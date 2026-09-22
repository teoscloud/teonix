# GPU AND DISPLAY POLICY — mainframe (Dell Precision T7810, board 0KJCC5)
#
# Deliberately card-agnostic. This chassis has no onboard and no BMC video, so the
# fitted card is the only POST path *and* the only way into the BIOS. That makes a
# GPU swap a two-way street: the machine must boot with whatever card is in the
# slot, including the old one if the new one has to come back out. So nothing here
# is conditional on a build-time choice of card — the only card-specific values are
# the display bandwidth budgets, and those are picked at boot from what is actually
# on the PCI bus (teonix-gpu-profile, below).
#
# Cards this has been written against:
#   1002:67df  Sapphire RX 580 (Polaris 10, DCE 11.2) — no DSC, hard mode ban
#   8086:56xx  Intel Arc A750/A770 (DG2 Alchemist, i915) — DSC, no ban; G9 must
#              be the last DP connector for the two-pipe 240 mode (see below)
#
# 2026-09-21, Arc fitted: the Polaris-specific workarounds (amdgpu initrd and
# module params, s2idle pin, greeter monitors.xml purge, the G9 EDID override)
# were removed. What is left is the card-agnostic budget mechanism.
#
# Board-level protection (no-video recovery, storage health) lives in
# ./gpu-guard.nix and is not card-specific either. See ./GPU.md for the history.
{ lib, pkgs, ... }:

{
  # ------------------------------------------------------------------ early KMS
  #
  # i915 for DG2/Alchemist, loaded from the initrd for two reasons. Determinism:
  # udev coldplug once silently failed to insert a DRM driver here (2026-09-10)
  # and the session degraded to simpledrm + llvmpipe. Driver choice: kernel 6.18
  # has *both* i915 and xe advertising the Arc PCI IDs (56a0/56a1/56a5) with
  # empty force_probe lists, so whichever loads first binds the card. Only i915 is
  # in the initrd, so i915 wins every time — the mature display stack for
  # Alchemist. If a future Intel card needs xe instead, add it here and drop i915.
  # Harmless with a non-Intel card fitted: no device, no bind.
  #
  # The Polaris-era extras (hardware.amdgpu.initrd, amdgpu.runpm=0,
  # amdgpu.gpu_recovery=1) were dropped on 2026-09-21 with the Arc fitted; with
  # an AMD card back in, amdgpu still loads from udev like on any other host.
  boot.initrd.kernelModules = [ "i915" ];

  # DG2 will not initialise without its GuC/HuC/DMC blobs (dg2_guc_70.bin,
  # dg2_huc_gsc.bin, dg2_dmc_ver2_0*.bin). not-detected.nix already turns this on
  # by default; state it explicitly so a regenerated hardware-configuration.nix
  # cannot quietly take the firmware away and leave the card dark.
  hardware.enableRedistributableFirmware = true;

  # VAAPI (iHD) and QSV for Intel Gen12+/DG2. Mesa already provides the OpenGL
  # (iris) and Vulkan (ANV) drivers, so nothing extra is needed to render. The
  # AMD ROCm ICDs in modules/hardware/hardware-x86.nix stay: both sets are inert
  # when their card is absent, which is the whole point.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver
    vpl-gpu-rt
  ];

  # The generic KMS DDX instead of a card-specific one. system-services.nix pins
  # [ "amdgpu" ] for every x86 host; on this one that pin would leave Xorg with no
  # usable driver the moment the card is not AMD. modesetting drives amdgpu and
  # i915 equally well, and the Wayland sessions (GDM greeter, Hyprland) do not
  # consult this at all — it only matters for an X fallback and for Xwayland's
  # host server, neither of which needs a vendor DDX.
  services.xserver.videoDrivers = lib.mkForce [ "modesetting" ];

  # Suspend policy is the kernel default again (deep S3 where the firmware offers
  # it). The s2idle pin and SuspendState=freeze were a Polaris workaround: the RX
  # 580 failed to re-POST on resume from deep on 2026-09-10 and wedged the card.
  # Dropped 2026-09-21 with the Arc fitted. If a resume ever comes back dark on
  # this chassis, gpu-guard.nix powers off rather than reboots, and the first
  # thing to try is `mem_sleep_default=s2idle` back in boot.kernelParams.

  # ------------------------------------------------------- resizable BAR (Arc)
  #
  # i915 tries to grow the Arc's VRAM aperture (BAR 2) from 256 MiB to the full
  # 8 GiB at probe and the firmware-sized root-port window is too small for it:
  #
  #   i915 0000:07:00.0: BAR 2 [mem size 0x200000000 64bit pref]: can't assign; no space
  #   i915 0000:07:00.0: Failed to resize BAR2 to 8192M (-ENOSPC)
  #   i915 0000:07:00.0: Using a reduced BAR size of 256MiB
  #
  # Above-4G decoding is already on (the window sits at 0x33fe0000000); what is
  # missing is a window big enough. pci=realloc lets the kernel reassign bridge
  # windows instead of trusting the firmware sizes, which is the documented way
  # to let that resize succeed. Small-BAR i915 means only 256 MiB of the 8 GiB
  # is CPU-visible and everything the CPU touches must be migrated through it.
  # Verify after a reboot: `lspci -vs 07:00.0` shows Region 2 [size=8G] and the
  # three lines above are gone from `journalctl -k`. If it does not take,
  # `pci=realloc,nocrs` is the next step. If the machine fails to boot, edit the
  # entry in the boot menu and drop the parameter; nothing else here depends on it.
  boot.kernelParams = [ "pci=realloc" ];

  # ------------------------------------------------- display bandwidth budgets
  #
  # display-safe.sh reads /run/teonix/display-bandwidth.conf if it exists and this
  # file otherwise, and applies no limits at all if neither is there. So this is
  # the fallback that applies when the profile service below has not run or could
  # not identify the card, and it deliberately carries the *most conservative*
  # numbers we have — the RX 580's. Being stuck at 60 Hz on a card that could do
  # more is an annoyance; letting an over-budget mode through on Polaris cost a
  # CMOS reset. Failing safe means failing slow.
  environment.etc."teonix/display-bandwidth.conf".text = ''
    # Fallback budgets, written by hosts/mainframe/gpu.nix. The per-card profile in
    # /run/teonix/display-bandwidth.conf overrides these; see teonix-gpu-profile.
    TEONIX_MAX_REFRESH_MULTI_OUTPUT=60
    TEONIX_MAX_PIXEL_RATE_MPS=450
  '';

  # Pick the budgets from the card that is actually fitted, before anything can
  # ask for a mode. Located by PCI display class, never by bus address: reseating
  # the card on 2026-09-10 already moved the ultrawide from DP-2 to DP-1.
  systemd.services.teonix-gpu-profile = {
    description = "Write the display bandwidth profile for the fitted GPU";
    wantedBy = [ "multi-user.target" "display-manager.service" ];
    before = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -u
      mkdir -p /run/teonix
      rm -f /run/teonix/gpu-note

      id=""
      for d in /sys/bus/pci/devices/*; do
        [ -r "$d/class" ] || continue
        case "$(cat "$d/class")" in
          0x03*)
            v="$(cat "$d/vendor" 2>/dev/null)"
            p="$(cat "$d/device" 2>/dev/null)"
            id="''${v#0x}:''${p#0x}"
            break
            ;;
        esac
      done

      if [ -z "$id" ]; then
        # gpu-boot-guard owns this case; all we do is not overwrite the fallback.
        echo "teonix-gpu-profile: no PCI display device found, keeping /etc budgets"
        exit 0
      fi

      # cap = refresh ceiling for secondary outputs while more than one is on.
      # px  = hard per-output ban in megapixels/second, checked for every mode.
      note=""
      case "$id" in
        1002:67df)
          name="Radeon RX 580 (Polaris 10, DCE 11.2)"
          # 5120x1440@120 is ~885 Mpx/s and has proven destructive here, while
          # both sanctioned G9 modes (5120x1440@60, 2560x1440@120) are ~442.
          # 450, not 500: the G9's full EDID also carries 3840x1080@120 (~498),
          # which is untested on Polaris and would otherwise become the pick
          # for high-refresh mode once refresh rates are ranked by tier.
          cap=60
          px=450
          ;;
        8086:56*)
          name="Intel Arc (DG2/Alchemist)"
          # No ban. DSC over DP 1.4 carries the G9 at 5120x1440@240 (~1767
          # Mpx/s); that mode's 1.94 GHz pixel clock exceeds one DG2 pipe, so
          # i915 drives it with two ("bigjoiner": the primary's pipe plus the
          # NEXT one). Verified clean in Hyprland on 6.18.52 with all three
          # outputs lit, 2026-09-21 — but only once the G9 sat in the last DP
          # connector. Pipes are handed out first-fit in connector order by the
          # kernel, mutter and aquamarine alike, so with the G9 in DP-2 (pipe B)
          # the S27 in DP-4 held pipe C, every 240 modeset failed EINVAL in
          # Hyprland, and the 240 that GDM/GNOME did manage that day (pipe
          # pairing unknown) came out as a magnified top-left quarter. Cabling
          # is therefore part of the config: see the greeter layout below.
          #
          # 2026-09-22: budget set to 900 on purpose, which admits only the
          # single-pipe modes (5120x1440@120 ~885, 2560x1440@240 ~885) and bans
          # the two-pipe 240. Measured with the mouse moving: the render thread
          # sat at 88% cpu, 81% of it *sys*, ~4 ms per wakeup — the i915 commit
          # path for the bigjoiner mode is where the time goes, and the cursor
          # never felt fully smooth. 120 is the everyday mode; 2000 brings 240
          # back (Super+S then picks it again).
          cap=240
          px=900
          ;;
        10de:*)
          name="NVIDIA device $id"
          cap=240
          px=2000
          note="NVIDIA needs services.xserver.videoDrivers and a driver package; the modesetting-only setup in hosts/mainframe/gpu.nix will run on nouveau."
          ;;
        *)
          name="display device $id"
          cap=240
          px=2000
          note="No display bandwidth profile for $id: assuming a DSC-capable card with no mode ban. Add a case in hosts/mainframe/gpu.nix if this card needs limits."
          ;;
      esac

      cat > /run/teonix/display-bandwidth.conf <<EOF
      # Generated by teonix-gpu-profile for $name ($id). Do not edit: rewritten
      # every boot. Profiles live in hosts/mainframe/gpu.nix.
      TEONIX_MAX_REFRESH_MULTI_OUTPUT=$cap
      TEONIX_MAX_PIXEL_RATE_MPS=$px
      EOF

      echo "teonix-gpu-profile: $name ($id) -> ''${cap}Hz secondary cap, ''${px} Mpx/s per-output budget"

      if [ -n "$note" ]; then
        {
          echo ""
          echo "  teonix: display GPU is $name ($id)."
          echo "  $note"
          echo "  See hosts/mainframe/GPU.md."
          echo ""
        } > /run/teonix/gpu-note
        cat /run/teonix/gpu-note
      fi
    '';
  };

  # The greeter is allowed to keep its monitors.xml again. teonix-greeter-unpin
  # (delete /var/lib/gdm/seat0/config/monitors.xml before every greeter start)
  # was an amdgpu/DCE 11.2 workaround: on 2026-09-10 every stored config the RX
  # 580 was handed ended in a black login screen of "Page flip failed" loops.
  # Dropped 2026-09-21. On the Arc a stored greeter layout is *wanted*: left to
  # itself mutter takes the panel's preferred 5120x1440@240, the two-pipe mode,
  # and the one time it went wrong (2026-09-21) the result was a magnified
  # quarter that hid GDM's session chooser — a blind login screen. A login
  # screen gains nothing from 240 Hz, so the greeter is pinned to the
  # single-pipe 5120x1440@120; sessions pick their own mode (Hyprland: 240).
  # Mutter reads $XDG_CONFIG_DIRS/monitors.xml as its system default; a
  # user's own ~/.config/monitors.xml still wins inside a GNOME session. The
  # entries must match connector+vendor+product+serial and cover every connected
  # output, or mutter ignores the file and improvises (i.e. falls back to today's
  # behaviour, no worse). Serials are the panels' own — no EDID override in play.
  # Connector names: the G9 lives in the LAST DisplayPort connector (DP-4) on
  # purpose, since 2026-09-21. 5120x1440@240 needs two display pipes and i915
  # takes the pipe right after the primary's; kernel, mutter and aquamarine all
  # hand pipes out first-fit in connector order, so the panel that needs a spare
  # neighbour must enumerate last: A=ASUS (DP-1, the HDMI port is a DP PCON),
  # B=S27 (DP-2), C=G9 (DP-4), D free for the joiner. With the G9 in DP-2 the S27
  # held pipe C and every 240 modeset failed with EINVAL.
  # Coordinates must be non-negative (mutter's parser rejects "-1080" outright),
  # so the layout is shifted down by the S27's height: G9 at y=1080, ASUS
  # bottom-flush at (5120,1440), S27 in the G9's top-right corner at (3200,0).
  environment.etc."xdg/monitors.xml".text = ''
    <monitors version="2">
      <configuration>
        <layoutmode>logical</layoutmode>
        <logicalmonitor>
          <x>0</x>
          <y>1080</y>
          <scale>1</scale>
          <primary>yes</primary>
          <monitor>
            <monitorspec>
              <connector>DP-4</connector>
              <vendor>SAM</vendor>
              <product>LC49G95T</product>
              <serial>H4ZN900468</serial>
            </monitorspec>
            <mode>
              <width>5120</width>
              <height>1440</height>
              <rate>119.999</rate>
            </mode>
          </monitor>
        </logicalmonitor>
        <logicalmonitor>
          <x>5120</x>
          <y>1440</y>
          <scale>1</scale>
          <monitor>
            <monitorspec>
              <connector>DP-1</connector>
              <vendor>AUS</vendor>
              <product>VG245</product>
              <serial>JBLMQS097970</serial>
            </monitorspec>
            <mode>
              <width>1920</width>
              <height>1080</height>
              <rate>60.000</rate>
            </mode>
          </monitor>
        </logicalmonitor>
        <logicalmonitor>
          <x>3200</x>
          <y>0</y>
          <scale>1</scale>
          <monitor>
            <monitorspec>
              <connector>DP-2</connector>
              <vendor>SAM</vendor>
              <product>S27E590</product>
              <serial>HTQGA01931</serial>
            </monitorspec>
            <mode>
              <width>1920</width>
              <height>1080</height>
              <rate>60.000</rate>
            </mode>
          </monitor>
        </logicalmonitor>
      </configuration>
    </monitors>
  '';

  # Surface the profile note at login (mainframe only — the file is written by the
  # service above, which disappears with this module).
  environment.interactiveShellInit = ''
    [ -f /run/teonix/gpu-note ] && cat /run/teonix/gpu-note || true
  '';
}
