{ config, pkgs, inputs, ... }:

let
  pkgs-unstable = inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in

{

  hardware = {

    # Miscellaneous configurations

    bluetooth.enable = true;

    # Bluetooth settings
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    # Graphics settings
    graphics = {
      enable = true;
      enable32Bit = true;

      #package32 = pkgs-unstable.pkgsi686Linux.mesa.drivers;

      ## amdvlk: an open-source Vulkan driver from AMD
      #extraPackages = [ pkgs.amdvlk ];
      #extraPackages32 = [ pkgs.driversi686Linux.amdvlk ];

    };

  };

  
}
