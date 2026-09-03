{ apple-silicon, lib, ... }:

let
  # linux-asahi exists in no binary cache: nixpkgs policy keeps vendor kernels
  # out of the tree, and upstream's own cache is documented as non-functional
  # (docs/binary-cache.md). So whoever evaluates the kernel also compiles it —
  # hours on the laptop, and it OOMs on an 8 GB Mac.
  #
  # The way out is to stop asking for a kernel nobody has built. Building it
  # from apple-silicon's *own* pinned nixpkgs rather than ours reproduces
  # exactly the derivation the installer ISO used, which nixos-install already
  # realised into this Mac's store, so the switch reuses it and compiles
  # nothing. Following nixos-unstable here changes the hash and throws that
  # away for no benefit — nothing in userspace links against the kernel.
  #
  # Consequence: the kernel tracks the apple-silicon input, not nixos-unstable,
  # so routine updates never rebuild it. Bumping the apple-silicon release is
  # what moves the kernel, and that single build is unavoidable.
  asahiPkgs = import apple-silicon.inputs.nixpkgs {
    system = "aarch64-linux";
    overlays = [ apple-silicon.overlays.default ];
  };
in

{
  # detected.nix is written by /etc/applenix/stage2.sh on the Mac itself
  # (Touch Bar, m1n1 quirks, keyboard layout, swapfile). Absent off-device.
  imports = [
    apple-silicon.nixosModules.apple-silicon-support
  ]
  ++ lib.optional (builtins.pathExists ./detected.nix) ./detected.nix;

  # m1n1 is not an Asahi-overlay package, so it comes from the ambient set and
  # feeds uboot-asahi. Taking it from the same pin keeps the bootloader
  # prebuilt too, instead of rebuilding U-Boot for a one-hash difference.
  nixpkgs.overlays = [ (final: prev: { inherit (asahiPkgs) m1n1; }) ];

  # Shared bootloader is x86-only. Asahi needs systemd-boot and must not
  # touch EFI variables (Apple firmware / U-Boot owns the boot picker).
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = false;

  networking.networkmanager.wifi.backend = lib.mkDefault "iwd";
  networking.wireless.iwd.enable = lib.mkDefault true;

  # hardware.asahi.overlay is left alone on purpose: the module already
  # defaults to apple-silicon-support/packages/overlay.nix, and re-deriving it
  # here is what broke on release-2026-07-30 (linux-asahi dropped the
  # ignoreConfigErrors argument).
  hardware.asahi =
    let
      localFw = ./firmware/firmware.cpio;
      hasLocalFw = builtins.pathExists localFw;
    in
    {
      enable = true;
      setupAsahiSound = true;
      # mkForce: the module assigns this unconditionally from the ambient pkgs.
      pkgs = lib.mkForce asahiPkgs;
      # install.sh / stage2.sh copy vendorfw into ./firmware (gitignored).
      # Must be null when absent: the upstream default stats /boot/vendorfw,
      # which fails pure flake eval off-device.
      extractPeripheralFirmware = hasLocalFw;
      peripheralFirmwareDirectory = if hasLocalFw then ./firmware else null;
    };

  services.power-profiles-daemon.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="macsmc-battery", ATTR{charge_control_end_threshold}="80"
  '';

  # 6.18+ renamed apple_dcp → appledrm (release-2026-07-30).
  boot.kernelParams = [ "appledrm.show_notch=1" ];
}
