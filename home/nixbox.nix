{ config, pkgs, username, hostname, projectdir, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  # In your home.nix or equivalent
  home.file.".config/docker/daemon.json".text = ''
    {
      "data-root": "/home/teodor/mnt/qvo870/dockerdata"
    }
  '';

  # ✅ Export session variables
  home.sessionVariables = {
    # session variables
  };

  # ✅ Import modules from `home/hosts/nixbox/modules`
  imports = [
    ./hosts/nixbox/modules/zshaliases.nix  # ✅ Renamed from shell.nix
    ./hosts/nixbox/modules/dotfiles.nix
  ];

  services.udiskie = {
    enable = true;
    automount = true;  # Automatically mount new devices
    notify = true;     # Show notifications
    tray = "auto";     # Show tray icon only when devices are available
  };
}
