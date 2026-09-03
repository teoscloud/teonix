{ apple-silicon, lib, ... }:

{
  # detected.nix is written by /etc/applenix/stage2.sh on the Mac itself
  # (Touch Bar, m1n1 quirks, keyboard layout, swapfile). Absent off-device.
  imports = [
    apple-silicon.nixosModules.apple-silicon-support
  ]
  ++ lib.optional (builtins.pathExists ./detected.nix) ./detected.nix;

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
