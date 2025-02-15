{ config, pkgs, username, hostname, projectdir, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  # ✅ Export session variables
  home.sessionVariables = {
    # session variables
  };

  # ✅ Import modules from `home/hosts/nixbox/modules`
  imports = [
    ./hosts/nixbox/modules/zshaliases.nix  # ✅ Renamed from shell.nix
    ./hosts/nixbox/modules/dotfiles.nix
  ];
}
