{ config, hostname, ... }:

{
  networking = {
    hostName = hostname;

    networkmanager = {
      enable = true;
    };

    firewall = {
      allowedTCPPorts = [ 443 25565 ];
      allowedUDPPorts = [ 1194 25565 ];

      checkReversePath = false; # for nordvpn compatibility
    };

    wireguard.enable = true;

  };

  # nordvpn?
  chaotic.nordvpn.enable = true;
}
