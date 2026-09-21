# G9 EDID OVERRIDE — mainframe
#
# The Samsung Odyssey G9 (LC49G95T) does not hand Linux a usable EDID for its
# fast modes: the kernel ends up with a 2-block EDID that tops out at
# 2560x1440@120 and never sees 5120x1440@240 (the DisplayID block the panel
# ships is broken under Linux). customfiles/edid/g9.bin is the community-fixed
# 3-block EDID for this panel: base + CTA-861 + a valid DisplayID block carrying
# 5120x1440 @ 240/120/60, 2560x1440@240 and 3840x1080@240. All three checksums
# verify (edid-decode -c).
#
# Two rules drive how it is applied:
#
#  1. STRICTLY THE G9. The kernel's own knob (drm.edid_firmware=<connector>:file)
#     keys on a connector name, and connector names are per-card and per-port
#     (the G9 was DP-1 on the RX 580, is DP-2 on the Arc). A boot-time cmdline
#     would silently hand the G9's EDID to whatever ends up in that port. So this
#     is done from a oneshot instead: read the panel's real EDID on every DRM
#     connector, find the one whose product name is LC49G95T, and set the
#     override for that connector only, then force a re-probe. Port-agnostic,
#     identity-matched, and a no-op when the G9 is absent or off.
#
#  2. ONLY ON A CARD THAT CAN DRIVE IT. The override makes 5120x1440@240
#     (~1766 Mpx/s, DP 1.4 + DSC) the panel's *preferred* mode, and the GDM
#     greeter (mutter) takes preferred modes at face value. On the RX 580 (no
#     DSC, 500 Mpx/s budget) that would be a black login screen — exactly the
#     failure GPU.md documents. The oneshot therefore runs after
#     teonix-gpu-profile and applies the override only if the fitted card's
#     TEONIX_MAX_PIXEL_RATE_MPS budget covers that mode. Put the 580 back and
#     the G9 keeps its own EDID; nothing here needs a rebuild.
#
# Ordering: before display-manager.service, so the greeter and Hyprland never
# see the reduced EDID. Hyprland's default for the G9 stays 2560x1440@120 in
# hyprland.conf (present in both EDIDs with identical timings); Super+D via
# display-safe.sh is what escalates to 5120x1440@240 once this is in place.
#
# Caveat: drm.edid_firmware is a module-wide parameter, so once set it sticks
# to that connector name until reboot. Hot-swapping a *different* panel into
# the G9's port mid-session would give it the G9 EDID until the next boot. On
# this desk the G9 does not move; if that changes, clear it with
#   echo > /sys/module/drm/parameters/edid_firmware; echo detect > /sys/class/drm/<card>-<conn>/status
#
# Verify after boot:
#   journalctl -b -u teonix-g9-edid
#   journalctl -kb | grep -i 'external EDID'       # kernel: Got external EDID ... for connector "DP-x"
#   hyprctl monitors | grep 5120x1440@239          # in availableModes
{ config, pkgs, ... }:

let
  # Lives in the flake, no /etc/custom-files or --impure needed. Ends up as
  # <firmware>/lib/firmware/edid/g9.bin(.zst); the kernel searches
  # firmware_class.path, which NixOS points at the current system's firmware.
  g9Edid = pkgs.runCommandLocal "g9-edid-firmware" { } ''
    install -Dm444 ${../../customfiles/edid/g9.bin} $out/lib/firmware/edid/g9.bin
  '';

  # 5120x1440@239.58 is ~1766 Mpx/s. Anything below this budget cannot hold the
  # mode the override advertises as preferred.
  neededMpps = 1800;
in
{
  hardware.firmware = [ g9Edid ];

  systemd.services.teonix-g9-edid = {
    description = "Apply the fixed Odyssey G9 EDID to the G9's connector (identity-matched)";
    wantedBy = [ "multi-user.target" "display-manager.service" ];
    before = [ "display-manager.service" ];
    after = [ "teonix-gpu-profile.service" ];
    wants = [ "teonix-gpu-profile.service" ];
    path = [ pkgs.coreutils pkgs.gnugrep config.systemd.package ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -u
      tag="teonix-g9-edid"
      fw="edid/g9.bin"
      param=/sys/module/drm/parameters/edid_firmware

      if [ ! -w "$param" ]; then
        echo "$tag: $param not writable (CONFIG_DRM_LOAD_EDID_FIRMWARE missing?), leaving EDIDs alone"
        exit 0
      fi

      # Card budget from teonix-gpu-profile (/run), else the /etc fallback.
      TEONIX_MAX_PIXEL_RATE_MPS=0
      for f in /run/teonix/display-bandwidth.conf /etc/teonix/display-bandwidth.conf; do
        if [ -r "$f" ]; then . "$f"; break; fi
      done
      px="''${TEONIX_MAX_PIXEL_RATE_MPS:-0}"
      case "$px" in *[!0-9]*|"") px=0 ;; esac
      if [ "$px" -lt ${toString neededMpps} ]; then
        echo "$tag: fitted card budget is $px Mpx/s (< ${toString neededMpps}); it cannot hold 5120x1440@240, so the G9 keeps its own EDID"
        exit 0
      fi

      # Find the G9 by what the panel itself reports. Give a slow panel a few
      # seconds to come up; i915/amdgpu are already probed from the initrd.
      edid=""
      i=0
      while [ "$i" -lt 50 ]; do
        for e in /sys/class/drm/card*-*/edid; do
          [ -r "$e" ] || continue
          if grep -aq 'LC49G95T' "$e"; then edid="$e"; break 2; fi
        done
        i=$((i + 1))
        sleep 0.1
      done

      if [ -z "$edid" ]; then
        echo "$tag: no connected LC49G95T found, nothing to override"
        exit 0
      fi

      cdir="$(dirname "$edid")"
      conn="$(basename "$cdir")"
      conn="''${conn#card*-}"
      want="$conn:$fw"

      if [ "$(cat "$param")" = "$want" ]; then
        echo "$tag: $want already active"
        exit 0
      fi

      # Boot-time only. Swapping a connector's EDID and re-probing it under a
      # running compositor is a live hotplug with a changed mode list, and on
      # 2026-09-21 that left Hyprland showing a zoomed top-left quarter of the
      # G9 until the next login. At boot this unit is ordered before
      # display-manager so the case cannot arise; it can only be reached from a
      # `nixos-rebuild switch`, where the right answer is to wait for a reboot.
      if systemctl is-active --quiet display-manager.service; then
        echo "$tag: a graphical session is up; not re-probing $conn live. The override will apply at the next boot."
        exit 0
      fi

      echo "$want" > "$param"
      # Re-probe so the driver re-reads the EDID (now served from firmware).
      echo detect > "$cdir/status"

      # The fixed EDID is 3 blocks (384 bytes); the panel's own is 2 (256).
      size="$(wc -c < "$edid")"
      if [ "$size" -ge 384 ]; then
        echo "$tag: applied $fw to $conn ($size-byte EDID now in effect)"
      else
        echo "$tag: set $want but $conn still reports a $size-byte EDID; check 'journalctl -kb | grep -i edid'"
      fi
    '';
  };
}
