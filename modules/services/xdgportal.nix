{ config, pkgs, stable-pkgs, ... }:

{
  xdg.portal = {
    enable = true;

    config = {
      # Hyprland sessions: force ScreenCast/Screenshot to the Hyprland backend so screen
      # sharing (Vesktop/OBS/Chromium) negotiates against wlroots, not KDE/GTK. Without the
      # explicit interface lines the frontend can pick `kde` for ScreenCast and the picker
      # shows but the stream never starts.
      hyprland = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
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
