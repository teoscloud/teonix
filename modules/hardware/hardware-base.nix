{ config, pkgs, lib, ... }:

{
  hardware = {
    bluetooth.enable = true;
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    graphics = {
      enable = true;
      enable32Bit = lib.mkForce (pkgs.stdenv.hostPlatform.system == "x86_64-linux");
      extraPackages = with pkgs; [
        vulkan-loader
        vulkan-validation-layers
      ];
    };
  };
}
