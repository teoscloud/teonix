{ config, pkgs, stable-pkgs, username, lib, system ? "x86_64-linux", ... }:

{
  boot = {
    supportedFilesystems = [ "exfat" ];
    kernelModules = [ "kvm" "exfat" ];

    kernel.sysctl = {
      "vm.max_map_count" = 2147483642;
    };

    kernelParams = [
      "hid_apple.fnmode=0"
    ];
  };
}
