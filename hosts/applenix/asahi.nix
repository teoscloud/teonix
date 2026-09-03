{ apple-silicon, lib, ... }:

{
  imports = [ apple-silicon.nixosModules.apple-silicon-support ];

  nixpkgs.overlays = [ apple-silicon.overlays.apple-silicon-overlay ];

  # Shared bootloader is x86-only. Asahi needs systemd-boot and must not
  # touch EFI variables (Apple firmware / U-Boot owns the boot picker).
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = false;

  networking.networkmanager.wifi.backend = lib.mkDefault "iwd";
  networking.wireless.iwd.enable = lib.mkDefault true;

  hardware.asahi =
    let
      localFw = ./firmware/firmware.cpio;
      hasLocalFw = builtins.pathExists localFw;
    in
    {
      setupAsahiSound = true;
      # Off-device / missing copy: do not stat /boot/asahi (breaks flake eval).
      # bootstrap.sh copies vendorfw into ./firmware (gitignored).
      extractPeripheralFirmware = hasLocalFw;
      peripheralFirmwareDirectory = lib.mkIf hasLocalFw ./firmware;
    };

  services.power-profiles-daemon.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="macsmc-battery", ATTR{charge_control_end_threshold}="80"
  '';

  boot.kernelParams = [ "apple_dcp.show_notch=1" ];
}
