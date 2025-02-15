{ config, pkgs, ... }:

{
  hardware = {
    firmware = [
      (
        pkgs.runCommand "g9.bin" { } ''
          mkdir -p $out/lib/firmware/edid
          cp ${./customfiles/edid/g9.bin} $out/lib/firmware/edid/g9.bin
        ''
      )
    ];
  };

  # Pass EDID file to the kernel
  boot.kernelParams = [
    "drm.edid_firmware=DP-1:/lib/firmware/edid/g9.bin"
  ];
}
