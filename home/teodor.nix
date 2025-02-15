{ config, pkgs, username, hostname, ... }:

{
  home.username = username;  # ✅ Now correctly receives username from flake.nix
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  # Example: Set an environment variable for your hostname
  home.sessionVariables = {
    HOSTNAME = hostname;
  };

  # Import modular configurations
  imports = [
    ./modules/dotfiles.nix  # ✅ Symlinks all dotfiles
    ./modules/monitor.nix   # Device-specific monitor config
  ];
}
