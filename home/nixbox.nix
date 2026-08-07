{ config, pkgs, username, hostname, projectdir, ... }:

{
  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

  # BusChain Control → Quickshell mixer / HW scroll strip
  home.sessionVariables = {
    BUSCHAIN_CONTROL_QS_MIXER = "1";
    BUSCHAIN_CONTROL_QS_STRIP = "1";
  };

  # In your home.nix or equivalent
  home.file.".config/docker/daemon.json".text = ''
    {
      "data-root": "/home/teodor/mnt/qvo870/dockerdata"
    }
  '';

  # ✅ Import modules from `home/hosts/nixbox/modules`
  imports = [
    ./hosts/nixbox/modules/zshaliases.nix  # ✅ Renamed from shell.nix
    ./hosts/nixbox/modules/dotfiles.nix
    ./hosts/nixbox/modules/hyprflow.nix
  ];

  services.udiskie = {
    enable = true;
    automount = true;  # Automatically mount new devices
    notify = true;     # Show notifications
    tray = "never";    # Disabled: tray icon hover triggered Hyprland CPopup::onCommit crash
  };

  # Quickshell owns org.freedesktop.Notifications — mask swaync's user unit
  # (swaynotificationcenter ships WantedBy=graphical-session.target)
  home.activation.disableSwaync = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    systemctl --user stop swaync.service 2>/dev/null || true
    systemctl --user mask swaync.service 2>/dev/null || true
  '';
}
