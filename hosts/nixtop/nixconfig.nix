{ config, pkgs, stable-pkgs, lib, ... }:

{
  nix.settings = {
    max-jobs = "auto";
    cores = 0;
  };
}
