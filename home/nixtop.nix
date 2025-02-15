{ config, pkgs, username, hostname, projectdir, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  home.sessionVariables = {
    HOSTNAME = hostname;
    PROJECT_DIR = projectdir;
    HYPRMONITORCONF = "${config.home.homeDirectory}/.config/hypr/monitor.conf";
  };

  imports = [
    ./modules/shell.nix
    ./modules/monitor.nix
    ./modules/dotfiles.nix
  ];
}
