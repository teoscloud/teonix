{ config, pkgs, stable-pkgs, lib, ... }:

{
  nix.settings = {
    max-jobs = 1;
    cores = 18; 
  };
}
