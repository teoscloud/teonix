{ config, hostname, ... }:

{
  networking = {
    hostName = hostname;

    networkmanager = {
      enable = true;
    };

    firewall = {
      allowedTCPPorts = [ 443 3000 25565 25566 ];
      allowedUDPPorts = [ 1194 25565 25566 ];

      checkReversePath = false; # for nordvpn compatibility
    };

    wireguard.enable = true;

  };

  # nordvpn?
  #chaotic.nordvpn.enable = true;
}
