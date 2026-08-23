{ config, pkgs, ... }:

{
  hardware.graphics.extraPackages = with pkgs; [
    rocmPackages.clr.icd
    rocmPackages.rocm-runtime
    rocmPackages.rocminfo
  ];
}
