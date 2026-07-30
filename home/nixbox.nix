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

  # EasyEffects daemon — starts with graphical session (Hyprland login)
  services.easyeffects = {
    enable = true;
    preset = "truebass";
  };

  # Upstream/--gapplication-service often ignores --load-preset; force after start.
  systemd.user.services.easyeffects.Service.ExecStartPost =
    "${pkgs.easyeffects}/bin/easyeffects --load-preset truebass";

  # Ship preset + Scarlett autoload (force: replace previously unmanaged copies)
  home.file.".local/share/easyeffects/output/truebass.json" = {
    source = ./hosts/nixbox/dotfiles/config/easyeffects/output/truebass.json;
    force = true;
  };
  home.file.".local/share/easyeffects/autoload/output/alsa_output.usb-Focusrite_Scarlett_2i4_USB-00.HiFi__Line1__sink:[Out] Line1.json" = {
    source = ./hosts/nixbox/dotfiles/config/easyeffects/autoload/output/scarlett-line1-truebass.json;
    force = true;
  };
}
