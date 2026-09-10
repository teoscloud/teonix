# Board-level display safety for the Dell Precision T7810 (board 0KJCC5).
#
# This chassis has NO onboard and NO BMC video: the discrete card is the only
# POST path. When it is missing or wedged there is no BIOS access either, and the
# only recovery is a full power drain. On 2026-09-10 that cost a CMOS reset after
# six consecutive warm reboots came up with zero display devices on the PCI bus.
#
# A warm reboot keeps PCIe slot power up, so it cannot clear a wedged card. These
# guards turn that dead end into a single power-button press by choosing poweroff
# over reboot.
#
# Deliberately GPU-agnostic: devices are located by PCI display class and we only
# require that *some* driver is bound. Keep this module across GPU swaps.
#
# Escape hatch, because these units can power the machine off:
#   touch /etc/teonix/no-gpu-guard        (persistent), or
#   teonix.no_gpu_guard                   (kernel command line, one boot)
{ config, lib, pkgs, ... }:

let
  guardHelpers = ''
    guard_disabled() {
      if [ -e /etc/teonix/no-gpu-guard ]; then
        echo "teonix-gpu-guard: disabled by /etc/teonix/no-gpu-guard"
        return 0
      fi
      if grep -qw teonix.no_gpu_guard /proc/cmdline 2>/dev/null; then
        echo "teonix-gpu-guard: disabled by teonix.no_gpu_guard kernel param"
        return 0
      fi
      return 1
    }

    # Print the sysfs path of the first PCI display controller (class 0x03xxxx).
    # No vendor, driver name or bus address is assumed anywhere.
    find_display_device() {
      for d in /sys/bus/pci/devices/*; do
        [ -r "$d/class" ] || continue
        case "$(cat "$d/class")" in
          0x03*) printf '%s' "$d"; return 0 ;;
        esac
      done
      return 1
    }

    drm_connectors_present() {
      for c in /sys/class/drm/card*-*/status; do
        [ -r "$c" ] && return 0
      done
      return 1
    }

    gpu_healthy() {
      dev="$(find_display_device)" || return 1
      [ -e "$dev/driver" ] || return 1
      drm_connectors_present || return 1
      return 0
    }
  '';

  guardPath = with pkgs; [ coreutils gnugrep systemd ];
in
{
  environment.etc."teonix/README".text = ''
    teonix GPU guards (hosts/mainframe/gpu-guard.nix)

    This machine has no onboard video, so a missing or wedged GPU means no BIOS
    access. gpu-boot-guard and gpu-resume-guard detect that and power the machine
    off rather than reboot, because only a cold start re-POSTs the card.

    To disable both guards:
      touch /etc/teonix/no-gpu-guard
    or boot once with the kernel parameter:
      teonix.no_gpu_guard

    Useful when deliberately running this box headless with no GPU fitted.
  '';

  # Runs after every resume. WantedBy+After on the sleep targets is the documented
  # way to hook post-resume work.
  systemd.services.gpu-resume-guard = {
    description = "Verify the GPU survived resume; cold power off if it did not";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" "suspend-then-hibernate.target" ];
    path = guardPath;
    serviceConfig.Type = "oneshot";
    script = ''
      ${guardHelpers}

      if guard_disabled; then exit 0; fi

      i=1
      while [ "$i" -le 15 ]; do
        if gpu_healthy; then
          echo "teonix-gpu-guard: GPU healthy after resume (attempt $i)"
          exit 0
        fi
        sleep 1
        i=$((i + 1))
      done

      dev="$(find_display_device || true)"
      if [ -n "$dev" ] && [ -w "$dev/reset" ]; then
        echo "teonix-gpu-guard: GPU unhealthy after resume; attempting PCI reset of $(basename "$dev")"
        echo 1 > "$dev/reset" || true
        sleep 5
        if gpu_healthy; then
          echo "teonix-gpu-guard: GPU recovered after PCI reset"
          exit 0
        fi
      fi

      echo "teonix-gpu-guard: GPU did not come back after resume."
      echo "teonix-gpu-guard: powering off instead of rebooting — a warm reboot keeps"
      echo "teonix-gpu-guard: slot power up and the firmware cannot re-POST the card."
      systemctl --no-block poweroff
    '';
  };

  # Catches the state that actually stranded the machine: booting with no GPU on
  # the bus at all. Single-shot via a marker so it can never loop.
  systemd.services.gpu-boot-guard = {
    description = "Cold power off a headless boot caused by a missing GPU";
    after = [ "sshd.service" ];
    wantedBy = [ "multi-user.target" ];
    path = guardPath;
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "teonix";
    };
    script = ''
      ${guardHelpers}

      marker=/var/lib/teonix/headless-boot

      if guard_disabled; then exit 0; fi

      if dev="$(find_display_device)"; then
        rm -f "$marker"

        # Device present — but also make sure a kernel driver actually bound.
        # On 2026-09-10 the GPU enumerated fine yet amdgpu was never inserted, and
        # the session silently degraded to simpledrm + llvmpipe. Warn only: such a
        # session is usable and a clean reboot fixes it (amdgpu is in the initrd).
        i=1
        while [ "$i" -le 30 ]; do
          if [ -e "$dev/driver" ]; then exit 0; fi
          sleep 1
          i=$((i + 1))
        done

        mkdir -p /run/teonix
        {
          echo ""
          echo "  teonix: the display GPU at $(basename "$dev") has NO kernel driver bound."
          echo "  This session is on the firmware framebuffer with software rendering."
          echo "  Fix: finish your work and reboot; amdgpu loads from the initrd."
          echo ""
        } > /run/teonix/gpu-driverless
        cat /run/teonix/gpu-driverless
        exit 0
      fi

      if [ -e "$marker" ]; then
        echo "teonix-gpu-guard: still no display device after a cold power cycle."
        echo "teonix-gpu-guard: staying up headless so SSH remains available."
        echo "teonix-gpu-guard: reseat the card, or touch /etc/teonix/no-gpu-guard."
        exit 0
      fi

      : > "$marker"
      sync

      echo "teonix-gpu-guard: no PCI display device found — this boot is headless."
      echo "teonix-gpu-guard: powering off in 60s so the next start cold-POSTs the card."
      echo "teonix-gpu-guard: cancel over SSH with: systemctl stop gpu-boot-guard"
      sleep 60
      systemctl --no-block poweroff
    '';
  };

  # The root NVMe dropped writes on 2026-09-10 ("lost async page write", journald
  # unable to rotate) after being moved to another slot, and this platform denies
  # the OS AER control so PCIe link errors mostly go unlogged. Track SMART error
  # counters across boots and complain at login when they grow. Warn only.
  environment.systemPackages = [ pkgs.smartmontools ];

  systemd.services.teonix-storage-health = {
    description = "Warn when NVMe SMART error counters grew since the previous boot";
    wantedBy = [ "multi-user.target" ];
    path = with pkgs; [ smartmontools coreutils gawk ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "teonix";
    };
    script = ''
      mkdir -p /run/teonix
      rm -f /run/teonix/storage-health
      warn=""

      for ctrl in /dev/nvme[0-9]; do
        [ -e "$ctrl" ] || continue
        out="$(smartctl -A "$ctrl" 2>/dev/null)" || continue

        crit="$(printf '%s\n' "$out"   | awk -F: '/Critical Warning/            { gsub(/[ \t,]/,"",$2); print $2 }')"
        media="$(printf '%s\n' "$out"  | awk -F: '/Media and Data Integrity/    { gsub(/[ \t,]/,"",$2); print $2 }')"
        errlog="$(printf '%s\n' "$out" | awk -F: '/Error Information Log/       { gsub(/[ \t,]/,"",$2); print $2 }')"
        media="''${media:-0}"; errlog="''${errlog:-0}"; crit="''${crit:-0x00}"

        state="/var/lib/teonix/nvme-health.$(basename "$ctrl")"
        prev_media=0; prev_errlog=0
        [ -r "$state" ] && read -r prev_media prev_errlog < "$state" || true
        printf '%s %s\n' "$media" "$errlog" > "$state"

        msg=""
        if [ "$crit" != "0x00" ]; then msg="$msg critical-warning=$crit"; fi
        if [ "$media" -gt "$prev_media" ]; then msg="$msg media-errors=$media(was:$prev_media)"; fi
        if [ "$errlog" -gt "$prev_errlog" ]; then msg="$msg error-log-entries=$errlog(was:$prev_errlog)"; fi

        if [ -n "$msg" ]; then
          warn="$warn  $(basename "$ctrl"):$msg"$'\n'
        fi
        echo "teonix-storage-health: $(basename "$ctrl") media=$media errlog=$errlog crit=$crit"
      done

      if [ -n "$warn" ]; then
        {
          echo ""
          echo "  teonix: NVMe SMART error counters changed — the disk is dropping or"
          echo "  logging errors. Check seating/slot, then: sudo smartctl -a /dev/nvme0"
          printf '%s' "$warn"
          echo ""
        } > /run/teonix/storage-health
        cat /run/teonix/storage-health
      fi
    '';
  };

  # Surface both warnings at login. /run is per-boot, so notes never go stale.
  environment.interactiveShellInit = ''
    for _tf in /run/teonix/gpu-driverless /run/teonix/storage-health; do
      [ -f "$_tf" ] && cat "$_tf"
    done
    unset _tf
    true
  '';
}
