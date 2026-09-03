{ apple-silicon, lib, ... }:

{
  imports = [ apple-silicon.nixosModules.apple-silicon-support ];

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
      enable = true;
      setupAsahiSound = true;
      extractPeripheralFirmware = hasLocalFw;
      # Must set null when absent — upstream default stats /boot/vendorfw at eval time.
      peripheralFirmwareDirectory = if hasLocalFw then ./firmware else null;
      overlay = import "${apple-silicon}/apple-silicon-support/packages/overlay.nix";
    };

  services.power-profiles-daemon.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="macsmc-battery", ATTR{charge_control_end_threshold}="80"
  '';

  # 6.18+ renamed apple_dcp → appledrm (release-2026-07-30).
  boot.kernelParams = [ "appledrm.show_notch=1" ];
}
