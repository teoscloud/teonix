{ config, hostname, ... }:

{
  networking = {
    hostName = hostname;

    networkmanager = {
      enable = true;
    };

    firewall = {
      allowedTCPPorts = [ 443 3000 3001 3002 3003 8000 54321 54323 25565 25566 11434 ];
      allowedUDPPorts = [ 1194 49152 25565 25566 ];

      checkReversePath = false; # for nordvpn compatibility
    };

    wireguard.enable = true;

  };

  # nordvpn?
  #chaotic.nordvpn.enable = true;
}
