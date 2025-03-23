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
    ./hosts/default/modules/zshaliases.nix  # ✅ Renamed from shell.nix
    ./hosts/default/modules/dotfiles.nix
  ];

  services.udiskie = {
    enable = true;
    automount = true;  # Automatically mount new devices
    notify = true;     # Show notifications
    tray = "auto";     # Show tray icon only when devices are available
  };
}
