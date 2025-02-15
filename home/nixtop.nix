{ config, pkgs, username, hostname, projectdir, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  # ✅ Export session variables
  home.sessionVariables = {
    # session variables
  };

  # ✅ Import modules from `home/hosts/nixtop/modules`
  imports = [
    ./hosts/nixtop/modules/zshaliases.nix  # ✅ Renamed from shell.nix
    ./hosts/nixtop/modules/dotfiles.nix
  ];
}
