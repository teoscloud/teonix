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
#   8086:56xx  Intel Arc A750/A770 (DG2 Alchemist, i915) — DSC, no ban needed
#
# Board-level protection (no-video recovery, storage health) lives in
# ./gpu-guard.nix and is not card-specific either. See ./GPU.md for the history.
{ lib, pkgs, ... }:

{
  # ------------------------------------------------------------------ early KMS
  #
  # Load the display driver from the initrd rather than trusting udev coldplug: on
  # 2026-09-10 coldplug silently failed to insert amdgpu (all DRM deps loaded, the
  # module never appeared) and the session degraded to simpledrm + llvmpipe, with
  # one fake Unknown-1 output and no EDID. Never insert a DRM driver by hand into
  # such a session — the takeover kills the compositor to a TTY. Doing it from the
  # initrd also gives native-res consoles and removes the simpledrm handover gap.
  hardware.amdgpu.initrd.enable = true;

  # i915 for DG2/Alchemist. It is in the initrd for the same determinism, and for
  # a second reason: kernel 6.18 has *both* i915 and xe advertising the Arc PCI IDs
  # (56a0/56a1/56a5) with empty force_probe lists, so whichever loads first binds
  # the card. Only i915 is in the initrd, so i915 wins every time — the mature
  # display stack for Alchemist. If a future Intel card needs xe instead, add it
  # here and drop i915. Harmless with an AMD card fitted: no device, no bind.
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

  boot.kernelParams = [
    # Freeze instead of entering S3. Polaris failed to re-POST on resume from deep
    # and wedged the card (2026-09-10, one suspend followed by six boots with zero
    # PCI lines for it). Alchemist is not known to have that bug, but the cost of
    # s2idle here is a few watts while the cost of a failed resume on this chassis
    # is a full power drain with no BIOS access in between — and long sleeps land
    # in S4 anyway (HibernateDelaySec in ./platform.nix), where the firmware POSTs
    # the card on the way back. Revisit only with an SSH session open.
    "mem_sleep_default=s2idle"
    # Both are amdgpu module parameters: ignored outright when amdgpu is not the
    # driver, so they can stay for the RX 580's sake either way. Runtime D3cold is
    # a second Polaris wedge path, and a reset attempt beats staying hung.
    "amdgpu.runpm=0"
    "amdgpu.gpu_recovery=1"
  ];

  # Belt and braces: even if the kernel param is lost, systemd must not pick deep.
  systemd.sleep.settings.Sleep.SuspendState = "freeze";

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
    TEONIX_MAX_PIXEL_RATE_MPS=500
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
          cap=60
          px=500
          ;;
        8086:56*)
          name="Intel Arc (DG2/Alchemist)"
          # DSC over DP 1.4 covers the G9 at 5120x1440@240 (~1769 Mpx/s), so the
          # budget only exists to keep something absurd from being selected.
          cap=240
          px=2000
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

  # The greeter must have NO stored monitors.xml — ever. Proven across six boots
  # on 2026-09-10 with the RX 580: every stored config that matched the connected
  # monitors left the login screen black with endless "Page flip failed:
  # drmModeAtomicCommit: Invalid argument", including a single plain 1080p60
  # panel (104 to 170 failures each). With no matching config mutter negotiates
  # its own layout and degrades it until something sticks, which worked every
  # time. Mutter treats a stored config as policy and hammers a commit the driver
  # rejects, so the fix is the absence of a file.
  #
  # Kept across the GPU swap on purpose: it may well be an amdgpu/DCE 11.2 bug and
  # not apply to i915 at all, but the only thing it costs is a greeter that does
  # not remember its layout, and a black login screen on this chassis is expensive
  # to debug. Drop it once the new card has proven it can survive a stored config.
  #
  # RemainAfterExit off, so this runs before every greeter start: the file persists
  # on disk between boots and mutter can write a new one at any time.
  systemd.services.teonix-greeter-unpin = {
    description = "Remove stored greeter monitor configs (mutter must improvise here)";
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

  # Surface the profile note at login (mainframe only — the file is written by the
  # service above, which disappears with this module).
  environment.interactiveShellInit = ''
    [ -f /run/teonix/gpu-note ] && cat /run/teonix/gpu-note || true
  '';
}
