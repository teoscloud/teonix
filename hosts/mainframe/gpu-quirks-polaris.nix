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
{ ... }:

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

  # The greeter must have NO stored monitors.xml — ever. Proven across six boots
  # on 2026-09-10: every stored config that matched the connected monitors left
  # the login screen black with endless "Page flip failed: drmModeAtomicCommit:
  # Invalid argument", regardless of what it pinned (three outputs at 5120,
  # the ultrawide alone at 5120, at 2560, even a single 1080p60 panel — 104 to
  # 170 failures each). With no matching config, mutter negotiates its own
  # layout and that worked every time, including with all three monitors
  # attached (0 failures at 13:38). Mutter treats a stored config as policy and
  # hammers a commit this amdgpu/DCE 11.2 combination rejects; its own layout it
  # degrades until something sticks. So the fix is the absence of a file.
  #
  # This runs every greeter start (RemainAfterExit off): the file persists on
  # disk between boots, and mutter can write one of its own.
  systemd.services.teonix-greeter-unpin = {
    description = "Remove stored greeter monitor configs (mutter must improvise on this GPU)";
    wantedBy = [ "display-manager.service" ];
    before = [ "display-manager.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = false;
    };
    script = ''
      rm -f /var/lib/gdm/seat0/config/monitors.xml
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

  # Surface the staleness notice at login (mainframe only — the file is written
  # by the service above, which disappears with this module).
  environment.interactiveShellInit = ''
    [ -f /run/teonix/gpu-quirks-stale ] && cat /run/teonix/gpu-quirks-stale || true
  '';
}
