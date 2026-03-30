{ config, hostname, ... }:

{
  networking = {
    hostName = hostname;

    networkmanager = {
      enable = true;
    };

    firewall = {
      # TCP 8080: WordPress / other HTTP in Docker on LAN (rootless publishes on host; open here)
      allowedTCPPorts = [ 443 3000 3001 3002 3003 8000 8080 8082 54321 54323 25565 25566 11434 ];
      allowedUDPPorts = [ 1194 8000 8080 8082 49152 25565 25566 ];

      checkReversePath = false; # for nordvpn compatibility
    };

    wireguard.enable = true;

  };

  # nordvpn?
  #chaotic.nordvpn.enable = true;
}
