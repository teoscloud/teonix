{ config, pkgs, stable-pkgs, ... }:

{
  #xdg.portal = {
  #  enable = true;
  #  wlr.enable = true;

  #  extraPortals = [
  #    #pkgs.xdg-desktop-portal-gtk
  #    pkgs.xdg-desktop-portal
  #    pkgs.xdg-desktop-portal-wlr
  #  ];

  #  configPackages = [
  #    pkgs.xdg-desktop-portal-gtk
  #    pkgs.xdg-desktop-portal-hyprland
  #    pkgs.xdg-desktop-portal
  #  ];
  #};

  #xdg.portal.config.common.default = "*";

  xdg.portal = {
    enable = true;
    # Prefer Hyprland + GTK in Hyprland sessions so screencast/file dialogs match the compositor
    # (avoids KDE portal winning and odd Chromium/Brave behavior).
    config = {
      hyprland.default = [ "hyprland" "gtk" ];
    };
    extraPortals = [
      #pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal
      pkgs.kdePackages.xdg-desktop-portal-kde
      #pkgs.xdg-desktop-portal-wlr
      #pkgs.xdg-desktop-portal-hyprland
      #pkgs.xdg-desktop-portal-gnome
    ];

    configPackages = [
      pkgs.xdg-desktop-portal-gtk
      pkgs.xdg-desktop-portal-hyprland
      #pkgs.xdg-desktop-portal
    ];
  };
}
