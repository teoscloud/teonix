{ config, pkgs, ... }:

{
  systemd.user.services = {
    mpris-proxy = {
      enable = true;
      description = "Mpris proxy";
      after = [ "network.target" "sound.target" ];
      wantedBy = [ "default.target" ];

      # Use stable bluez package
      serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
    };
  };
}
