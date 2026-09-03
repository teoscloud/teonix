{ config, pkgs, stable-pkgs, unstable-pkgs, inputs, lib, ... }:

{
  nixpkgs.config.permittedInsecurePackages = [
    "dotnet-runtime-wrapped-6.0.36"
  ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = import ./package-set.nix {
    inherit unstable-pkgs stable-pkgs lib;
  };
}
