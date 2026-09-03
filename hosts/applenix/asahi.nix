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
      # Off-device / missing copy: do not stat /boot/vendorfw (breaks flake eval).
      # bootstrap.sh copies vendorfw into ./firmware (gitignored).
      extractPeripheralFirmware = hasLocalFw;
      peripheralFirmwareDirectory = lib.mkIf hasLocalFw ./firmware;
      # Unstable's common-config still flags unused CRYPTO_* / JITTERENTROPY
      # on the Asahi kernel. Do not fail linux-config for those.
      overlay = final: prev:
        let
          base = import "${apple-silicon}/apple-silicon-support/packages/overlay.nix" final prev;
        in
        base
        // {
          linux-asahi = final.callPackage "${apple-silicon}/apple-silicon-support/packages/linux-asahi" {
            ignoreConfigErrors = true;
          };
        };
    };

  services.power-profiles-daemon.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="macsmc-battery", ATTR{charge_control_end_threshold}="80"
  '';

  # 6.18+ renamed apple_dcp → appledrm (release-2026-07-30).
  boot.kernelParams = [ "appledrm.show_notch=1" ];
}
