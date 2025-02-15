{ config, pkgs, username, ... }:

{
  home.username = username;  # ✅ Now correctly receives username from flake.nix
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  programs.home-manager.enable = true;

  # Import modular configurations
  imports = [
    ./modules/dotfiles.nix  # ✅ Symlinks all dotfiles
  ];
}
