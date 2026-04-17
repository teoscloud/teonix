{ config, pkgs, stable-pkgs, ... }:

{
  xdg.portal = {
    enable = true;

    config = {
      # Hyprland sessions: use Hyprland portal for screencast/window, GTK for file dialogs
      hyprland.default = [ "hyprland" "gtk" ];
      # Plasma sessions: use KDE portal for everything
      common.default = [ "kde" "gtk" ];
    };

    extraPortals = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
      pkgs.kdePackages.xdg-desktop-portal-kde
    ];
  };
}
