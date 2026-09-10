# GPU-SPECIFIC QUIRKS — Sapphire RX 580 (Polaris 10, PCI 1002:67df, DCE 11.2)
#
# Every option in this file exists because of that one card. On a GPU swap:
# drop this import from flake.nix, rebuild, re-test suspend. See ./GPU.md.
#
# Why it exists: ACPI S3 cuts GPU context and Polaris fails to re-POST on resume.
# The card then wedges, and PCIe slot power survives a *warm* reboot — so the Dell
# UEFI cannot enumerate it and there is no POST video at all. This board has no
# onboard video, so that also means no BIOS access until a full power drain.
# Confirmed 2026-09-10: one suspend at 00:14:40 was followed by six boots with
# zero `pci 0000:05:00.0` lines.
{ lib, pkgs, ... }:

let
  expectedGpu = "1002:67df";

  # Refresh ceiling display-safe.sh may apply while more than one output is on.
  # 5120x1440@120 8bpc is ~25.4 Gbps against DP 1.4 HBR3's 25.92 Gbps usable, so
  # DCE 11.2 cannot validate a second pipe alongside it. Raise after a GPU upgrade.
  maxRefreshMultiOutput = 60;

  # Hard per-output pixel-rate budget in megapixels/second. Any mode above it is
  # BANNED for this card, no matter the monitor or port: 5120x1440@120 is ~885
  # Mpx/s and has proven destructive on this setup, while both sanctioned G9
  # modes — 5120x1440@60 and 2560x1440@120 — are ~442 Mpx/s (verified working
  # live on 2026-09-10 with two extra 1080p60 outputs attached). Drop this file
  # on a GPU upgrade and the ban disappears with it.
  maxPixelRateMps = 500;

  # ---------------------------------------------------------------- greeter pin
  #
  # display-safe.sh cannot reach the login greeter: GDM/mutter runs before any
  # session and would take the ultrawide's EDID-preferred mode, which is exactly
  # the banned 5120x1440@120. monitors.xml is the only lever mutter offers, and
  # it matches on connector plus EDID identity — so this is the one place in the
  # repo that must name a specific panel. It is quarantined here deliberately:
  # a GPU swap drops this file and the pin disappears with it.
  #
  # Only "ultrawide alone" layouts are listed, and that is sufficient rather than
  # lazy: with any second output attached the GPU refuses 5120x1440@120 outright
  # (verified 2026-09-10), so the banned mode is only reachable when this panel
  # is the sole monitor. Every connector the card can expose is enumerated, so
  # the pin still applies after moving the cable to a different port. If the
  # panel is ever replaced, nothing matches and mutter simply falls back.
  ultrawide = {
    vendor = "SAM";
    product = "LC49G95T";
    serial = "H4ZN900468";
    width = 5120;
    height = 1440;
    # 469000 kHz / (5280 x 1481) = 59.9769 Hz. mutter matches stored rates within
    # 0.001 Hz, so this value has to stay exact or the pin silently stops
    # matching and the greeter falls back to the banned mode. The same formula
    # reproduces mutter's own 119.999 for the 120 Hz mode, which is how it was
    # checked. Recompute from `edid-decode` if the panel or its firmware changes.
    rate = "59.977";
  };

  connectors = [
    "DP-1" "DP-2" "DP-3" "DP-4"
    "HDMI-A-1" "HDMI-A-2" "HDMI-A-3"
    "DVI-D-1" "DVI-I-1"
  ];

  configFor = connector: ''
      <configuration>
        <layoutmode>logical</layoutmode>
        <logicalmonitor>
          <x>0</x>
          <y>0</y>
          <scale>1</scale>
          <primary>yes</primary>
          <monitor>
            <monitorspec>
              <connector>${connector}</connector>
              <vendor>${ultrawide.vendor}</vendor>
              <product>${ultrawide.product}</product>
              <serial>${ultrawide.serial}</serial>
            </monitorspec>
            <mode>
              <width>${toString ultrawide.width}</width>
              <height>${toString ultrawide.height}</height>
              <rate>${ultrawide.rate}</rate>
            </mode>
          </monitor>
        </logicalmonitor>
      </configuration>
  '';

  monitorsXml = pkgs.writeText "teonix-greeter-monitors.xml" ''
    <monitors version="2">
    ${lib.concatMapStrings configFor connectors}</monitors>
  '';
in
{
  # Deterministic early KMS: load amdgpu from the initrd instead of relying on udev
  # coldplug, which silently failed to insert it on 2026-09-10 (all DRM deps loaded,
  # module never appeared -> session degraded to simpledrm + llvmpipe). Also gives
  # native-res consoles and removes the simpledrm->amdgpu black gap during boot.
  # AMD-specific rather than Polaris-specific: keep it for any future AMD card,
  # drop it with this file for a non-AMD card.
  hardware.amdgpu.initrd.enable = true;

  boot.kernelParams = [
    # Freeze instead of entering S3. The GPU keeps power, so the resume re-POST
    # that wedged the card is never attempted. Suspend still works.
    "mem_sleep_default=s2idle"
    # Polaris runtime D3cold is a second wedge path; power/control defaults to auto.
    "amdgpu.runpm=0"
    # Attempt a GPU reset rather than staying hung.
    "amdgpu.gpu_recovery=1"
  ];

  # Belt and braces: even if the kernel param is lost, systemd must not pick deep.
  systemd.sleep.settings.Sleep.SuspendState = "freeze";

  # Read by display-safe.sh so the caps live in exactly one place.
  environment.etc."teonix/display-bandwidth.conf".text = ''
    # Written by hosts/mainframe/gpu-quirks-polaris.nix. Raise on a GPU upgrade.
    TEONIX_MAX_REFRESH_MULTI_OUTPUT=${toString maxRefreshMultiOutput}
    TEONIX_MAX_PIXEL_RATE_MPS=${toString maxPixelRateMps}
  '';

  # Static fallback for the single-ultrawide case, in case the generated per-seat
  # file below is ever not picked up. Only the ultrawide is named here; other
  # panels are left entirely to mutter.
  environment.etc."xdg/monitors.xml".source = monitorsXml;

  # GDM 49+ moved the greeter's config into a per-seat directory owned by a
  # dynamic user, so /etc/xdg alone is not guaranteed to win. Place the same file
  # in both locations rather than betting on one. Ordered before the greeter
  # starts; deliberately does not touch the ownership or mode of GDM's own
  # directory, only the entry inside it.
  #
  # The per-seat file is *generated* rather than static, because a mutter config
  # only applies when it lists every connected monitor — there is no way to pin
  # one panel and let mutter improvise the rest. So the greeter config is built
  # at boot from the EDIDs actually present: no monitor, connector or card index
  # is named anywhere, each panel gets its own largest mode inside the pixel-rate
  # budget, and the biggest panel becomes primary at 0,0. An ultrawide therefore
  # gets its full width instead of mutter guessing, and a 1440p panel gets 1440p,
  # with the refresh ceiling still applied.
  #
  # Regenerated on every greeter start (RemainAfterExit is off), so a config
  # mutter might write for itself never survives.
  systemd.services.teonix-greeter-monitor-pin = {
    description = "Generate a greeter monitor layout this GPU can survive";
    wantedBy = [ "display-manager.service" ];
    before = [ "display-manager.service" ];
    path = with pkgs; [ python3 edid-decode ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    script = ''
      # Set by the watchdog below after it throws a layout mutter could not
      # commit. Regenerating the same file would undo the repair, so for the rest
      # of this boot the greeter is mutter's problem.
      if [ -e /run/teonix/greeter-no-pin ]; then
        echo "greeter repair in effect this boot; not generating a layout"
        exit 0
      fi
      install -d -m 0755 /var/lib/gdm/seat0
      [ -d /var/lib/gdm/seat0/config ] || install -d -m 0700 /var/lib/gdm/seat0/config
      python3 ${./greeter-monitors.py} /var/lib/gdm/seat0/config/monitors.xml
    '';
  };

  # Last resort. Mutter forces a stored layout even when it cannot commit it, and
  # the result is a black login screen whose only escape is unplugging a cable —
  # which is exactly what happened on 2026-09-10. If page flips are still failing
  # well after the greeter came up, and nobody has managed to log in, throw the
  # generated layout away and hand the greeter back to mutter's own logic, which
  # downgrades until it finds something the card will take.
  #
  # Two guards keep this from ever disturbing a working session: it acts only
  # while no session of Class=user exists (checked twice, the second time
  # immediately before acting), and at most once per boot. The worst a false
  # positive can cost is one restart of a greeter nobody was using.
  #
  # The trigger is the count since boot, deliberately not the recent rate. A black
  # greeter goes quiet: 57 of the 170 failures on 2026-09-10 landed in the first
  # eight seconds and then stopped, because a static screen has nothing to repaint,
  # so a "still failing right now" test reads zero on a screen that is stone dead.
  # The counts separate cleanly anyway — 170 and 103 on the two broken boots
  # against 6 on a boot mutter fixed by itself — so 25 sits in open water.
  systemd.services.teonix-greeter-watchdog = {
    description = "Recover the login greeter if this GPU cannot commit its layout";
    wantedBy = [ "display-manager.service" ];
    after = [ "display-manager.service" ];
    path = with pkgs; [ systemd coreutils gnugrep gawk ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    script = ''
      flag=/run/teonix/greeter-repaired
      stand_down=/run/teonix/greeter-no-pin
      pin=/var/lib/gdm/seat0/config/monitors.xml

      if [ -e "$flag" ]; then
        echo "greeter already repaired this boot; standing by"
        exit 0
      fi

      user_session() {
        for s in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
          if [ "$(loginctl show-session "$s" -p Class --value 2>/dev/null)" = "user" ]; then
            return 0
          fi
        done
        return 1
      }

      # Let the greeter come up and settle before judging it.
      sleep 25

      if user_session; then
        echo "someone is logged in; the greeter did its job"
        exit 0
      fi
      if [ ! -f "$pin" ]; then
        echo "no pinned layout to blame"
        exit 0
      fi

      failures="$(journalctl -b -t gnome-shell --no-pager 2>/dev/null \
        | grep -c 'Page flip failed' || true)"
      if [ "''${failures:-0}" -lt 25 ]; then
        echo "greeter healthy ($failures page-flip failures this boot)"
        exit 0
      fi

      if user_session; then
        echo "a session appeared while checking; leaving the greeter alone"
        exit 0
      fi

      install -d -m 0755 /run/teonix
      : > "$stand_down"
      rm -f "$pin"
      # The static single-panel fallback could fail the same way, so this boot
      # gets no stored configuration at all. Activation restores it.
      rm -f /etc/xdg/monitors.xml
      cat > "$flag" <<'EOF'
      teonix: the login greeter could not commit its pinned monitor layout, so the
      teonix: layout was removed and GDM restarted once. See GPU.md, "Why the
      teonix: greeter only drives one monitor". A reboot tries the layout again.
      EOF
      chmod 0644 "$flag"

      echo "greeter failed $failures page flips with nobody logged in; dropping $pin and restarting the display manager"
      # --no-block: restarting the unit we are ordered after would otherwise have
      # us waiting on a job that is waiting on us.
      systemctl restart --no-block display-manager.service
    '';
  };

  # Tell us when these quirks outlive the card they were written for.
  systemd.services.teonix-gpu-quirks-staleness = {
    description = "Warn when the Polaris display quirks no longer match the fitted GPU";
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      found=""
      for d in /sys/bus/pci/devices/*; do
        [ -r "$d/class" ] || continue
        case "$(cat "$d/class")" in
          0x03*)
            found="$(cat "$d/vendor" 2>/dev/null):$(cat "$d/device" 2>/dev/null)"
            found="$(printf '%s' "$found" | tr -d '\n' | sed 's/0x//g')"
            break
            ;;
        esac
      done

      mkdir -p /run/teonix
      rm -f /run/teonix/gpu-quirks-stale

      if [ -z "$found" ]; then
        echo "teonix: no PCI display device present; cannot check quirk staleness"
        exit 0
      fi

      if [ "$found" != "${expectedGpu}" ]; then
        {
          echo ""
          echo "  teonix: display GPU is now $found, not ${expectedGpu} (RX 580 / Polaris)."
          echo "  The Polaris quirks in hosts/mainframe/gpu-quirks-polaris.nix are STALE:"
          echo "    - suspend is still forced to s2idle instead of deep S3"
          echo "    - the multi-output refresh cap is still ${toString maxRefreshMultiOutput} Hz"
          echo "  Follow the replacement checklist in hosts/mainframe/GPU.md."
          echo ""
        } > /run/teonix/gpu-quirks-stale
        cat /run/teonix/gpu-quirks-stale
      fi
    '';
  };

  # Surface this module's notices at login (mainframe only — both files are
  # written by services above, which disappear with this module).
  environment.interactiveShellInit = ''
    for _qf in /run/teonix/gpu-quirks-stale /run/teonix/greeter-repaired; do
      [ -f "$_qf" ] && cat "$_qf"
    done
    unset _qf
    true
  '';
}
