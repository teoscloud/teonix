{ config, hostname, ... }:

{
  networking = {
    hostName = hostname;

    networkmanager = {
      enable = true;
    };

    firewall = {
      # TCP 8080: WordPress / other HTTP in Docker on LAN (rootless publishes on host; open here)
      allowedTCPPorts = [ 443 3000 3001 3002 3003 3010 8000 8080 8082 54321 54323 25565 25566 11434 47823 ];
      allowedUDPPorts = [ 1194 3010 8000 8080 8082 49152 25565 25566 47823 ];

      # Mullvad / WireGuard: reverse path filtering can break VPN tunnels
      checkReversePath = false;
    };

    wireguard.enable = true;
  };
}
