{ config, pkgs, username, ... }:

{
  environment = {
    # for cachy
    #systemPackages = [ pkgs.lan-mouse_git ];
    variables.RUST_MIN_STACK = "16777216";

    # Optionally set system-wide environment variables
    sessionVariables = {
      NIXOS_OZONE_WL = "1";
      POLKIT_AUTH_AGENT = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
      XDG_SESSION_TYPE = "wayland";
      WLR_NO_HARDWARE_CURSORS = "1";
      MOZ_ENABLE_WAYLAND = "1";
      SDL_VIDEODRIVER = "wayland";
      _JAVA_AWT_WM_NONREPARENTING = "1";
      CLUTTER_BACKEND = "wayland";
      WLR_RENDERER = "vulkan";
      XDG_CURRENT_DESKTOP = "Hyprland";
      XDG_SESSION_DESKTOP = "Hyprland";
      GTK_USE_PORTAL = "1";
      NIXOS_XDG_OPEN_USE_PORTAL = "1";

      # for steam protonup to generate in the right dir
      STEAM_EXTRA_COMPAT_TOOLS_PATHS = 
        "/home/${username}/.steam/root/compatibilitytools.d";
    };
  };
}
