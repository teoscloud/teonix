{ config, pkgs, username, hostname, projectdir, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  home.sessionVariables = {
    HOSTNAME = hostname;
    PROJECT_DIR = projectdir;
  };

  imports = [
    ./modules/dotfiles.nix
    ./modules/monitor.nix
    ./modules/shell.nix
  ];
}
