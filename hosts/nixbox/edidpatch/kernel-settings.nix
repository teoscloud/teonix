{ config, pkgs, stable-pkgs, username, ... }:

{
  boot = {

    kernelParams = [
      "drm.edid_firmware=DP-1:edid/g9.bin"
      "video=DP-1:e"
      #"ipv6.disable=1"
    ];

  };
}
