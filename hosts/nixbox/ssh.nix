{ config, pkgs, ... }:

{
  # Enable OpenSSH server for local network connections only (no internet access)
  # 
  # This configuration allows your MacBook to connect to your NixOS machine
  # over your local network. External internet access is prevented by:
  # 1. Your router's NAT (standard home network setup)
  # 2. The firewall blocking external connections by default
  #
  # To connect from your MacBook:
  #   ssh username@<nixbox-local-ip>
  #   (Find the IP with: ip addr show or hostname -I)
  #
  # For Ollama tunneling (to use local models from MacBook via Cursor):
  #   ssh -L 11434:localhost:11434 username@<nixbox-local-ip>
  # Then configure Cursor to use: http://localhost:11434/v1
  
  services.openssh = {
    enable = true;
    
    # Listen on all network interfaces (allows MacBook on local network to connect)
    # Default behavior - listens on all interfaces
    # To restrict to specific interface, uncomment and modify:
    # listenAddresses = [
    #   { addr = "0.0.0.0"; port = 22; }  # IPv4 - all interfaces
    #   { addr = "::"; port = 22; }      # IPv6 - all interfaces
    # ];
    
    # Security settings
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = true;  # Set to false if using only key-based auth
      KbdInteractiveAuthentication = false;
      X11Forwarding = false;
      # Enable TCP forwarding for Ollama tunneling (allows SSH port forwarding)
      # This enables: ssh -L 11434:localhost:11434 user@host
      AllowTcpForwarding = true;
    };
    
    # Open firewall port 22 for SSH
    # The firewall will block external internet connections by default
    # Only devices on your local network will be able to connect
    openFirewall = true;
  };
}

