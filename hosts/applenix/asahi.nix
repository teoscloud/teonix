{ apple-silicon, ... }:

{
  imports = [ apple-silicon.nixosModules.apple-silicon-support ];

  nixpkgs.overlays = [ apple-silicon.overlays.apple-silicon-overlay ];

  hardware.asahi = {
    setupAsahiSound = true;
    # Omit peripheralFirmwareDirectory — firmware is read from ESP at boot (--impure rebuilds).
  };

  services.power-profiles-daemon.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="macsmc-battery", ATTR{charge_control_end_threshold}="80"
  '';

  boot.kernelParams = [ "apple_dcp.show_notch=1" ];
}
