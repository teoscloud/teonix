{ config, pkgs, inputs, ... }:

{

  hardware = {
    # Load custom EDID
    # REQUIRES mkdir -p /etc/custom-files/edid/ && sudo cp edid.bin /etc/custom-files/edid/
    firmware = [
      (
        pkgs.runCommand "g9.bin" { } ''
          mkdir -p $out/lib/firmware/edid
          cp ${/etc/custom-files/edid/g9.bin} $out/lib/firmware/edid/g9.bin
        ''
      )
    ];

  };
  
}
