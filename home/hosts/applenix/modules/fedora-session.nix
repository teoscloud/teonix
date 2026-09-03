# Asahi Fedora is kernel / GPU / PipeWire / greeter only.
# This module starts Nix Hyprland on top of that stack.
{
  config,
  pkgs,
  lib,
  username,
  ...
}:

let
  fontDir = ../../../../modules/customization/fonts;

  michroma = pkgs.stdenvNoCC.mkDerivation {
    pname = "michroma";
    version = "1.000";
    src = "${fontDir}/Michroma-Regular.ttf";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      cp $src $out/share/fonts/truetype/Michroma-Regular.ttf
    '';
  };

  vt323 = pkgs.stdenvNoCC.mkDerivation {
    pname = "vt323";
    version = "2.000";
    src = "${fontDir}/VT323-Regular.ttf";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      cp $src $out/share/fonts/truetype/VT323-Regular.ttf
    '';
  };

  shareTechMono = pkgs.stdenvNoCC.mkDerivation {
    pname = "share-tech-mono";
    version = "1.002";
    src = "${fontDir}/ShareTechMono-Regular.ttf";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/share/fonts/truetype
      cp $src $out/share/fonts/truetype/ShareTechMono-Regular.ttf
    '';
  };

  # Nix Hyprland links Nix Mesa, which cannot drive Asahi. Point GL/EGL/GBM
  # at Fedora's userspace before exec; apps inherit the session.
  hyprlandNixSession = pkgs.writeShellScriptBin "hyprland-nix-session" ''
    set -euo pipefail

    if [ -d /usr/lib64/dri ]; then
      export LIBGL_DRIVERS_PATH="/usr/lib64/dri''${LIBGL_DRIVERS_PATH:+:$LIBGL_DRIVERS_PATH}"
    fi
    if [ -d /usr/share/glvnd/egl_vendor.d ]; then
      export __EGL_VENDOR_LIBRARY_DIRS="/usr/share/glvnd/egl_vendor.d''${__EGL_VENDOR_LIBRARY_DIRS:+:$__EGL_VENDOR_LIBRARY_DIRS}"
    fi
    if [ -f /usr/share/glvnd/egl_vendor.d/50_mesa.json ]; then
      export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json
    fi
    if [ -d /usr/lib64/gbm ]; then
      export GBM_BACKENDS_PATH="/usr/lib64/gbm''${GBM_BACKENDS_PATH:+:$GBM_BACKENDS_PATH}"
    fi

    export XDG_CURRENT_DESKTOP=Hyprland
    export XDG_SESSION_DESKTOP=Hyprland
    export XDG_SESSION_TYPE=wayland

    if command -v systemctl >/dev/null; then
      systemctl --user import-environment \
        DISPLAY WAYLAND_DISPLAY \
        XDG_CURRENT_DESKTOP XDG_SESSION_TYPE XDG_SESSION_DESKTOP \
        LIBGL_DRIVERS_PATH __EGL_VENDOR_LIBRARY_DIRS \
        __EGL_VENDOR_LIBRARY_FILENAMES GBM_BACKENDS_PATH \
        2>/dev/null || true
      systemctl --user start graphical-session.target 2>/dev/null || true
    fi

    exec ${pkgs.hyprland}/bin/Hyprland "$@"
  '';
in
{
  # Profile + XDG hooks that NixOS would have set up for us.
  targets.genericLinux.enable = true;

  home.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    POLKIT_AUTH_AGENT = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
    GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
    XDG_SESSION_TYPE = "wayland";
    WLR_NO_HARDWARE_CURSORS = "1";
    MOZ_ENABLE_WAYLAND = "1";
    SDL_VIDEODRIVER = "wayland,x11";
    _JAVA_AWT_WM_NONREPARENTING = "1";
    CLUTTER_BACKEND = "wayland";
    XDG_CURRENT_DESKTOP = "Hyprland";
    XDG_SESSION_DESKTOP = "Hyprland";
    GTK_USE_PORTAL = "1";
    NIXOS_XDG_OPEN_USE_PORTAL = "1";
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "/home/${username}/.steam/root/compatibilitytools.d";
    RUST_MIN_STACK = "16777216";
  };

  # NixOS-only extras: compositor and portals live in programs.* there.
  home.packages = [
    hyprlandNixSession
    pkgs.hyprland
    pkgs.hypridle
    pkgs.hyprlock
    pkgs.xwayland
    pkgs.xdg-desktop-portal
    pkgs.xdg-desktop-portal-hyprland
    pkgs.xdg-desktop-portal-gtk
    pkgs.nerd-fonts.fira-code
    pkgs.font-awesome
    pkgs.noto-fonts
    pkgs.liberation_ttf
    pkgs.source-han-serif
    pkgs.ibm-plex
    pkgs._3270font
    michroma
    vt323
    shareTechMono
  ];

  fonts.fontconfig.enable = true;
  fonts.fontconfig.defaultFonts = {
    sansSerif = [ "Michroma" "IBM Plex Sans" "Noto Sans" ];
    emoji = [ "Apple Color Emoji" ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-hyprland
      pkgs.xdg-desktop-portal-gtk
    ];
    config = {
      hyprland = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "hyprland" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "hyprland" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "gtk" ];
      };
      common.default = [ "hyprland" "gtk" ];
    };
  };

  xdg.dataFile."wayland-sessions/hyprland-nix.desktop".text = ''
    [Desktop Entry]
    Name=Hyprland (Nix)
    Comment=Hyprland from teonix Home Manager
    Exec=${hyprlandNixSession}/bin/hyprland-nix-session
    TryExec=${hyprlandNixSession}/bin/hyprland-nix-session
    Type=Application
    DesktopNames=Hyprland
  '';

  # hyprland.conf still starts nixos-fake-graphical-session.target. On Fedora
  # that unit does not exist unless we provide it; bind it to the real target
  # so portals come up the same way.
  systemd.user.targets.nixos-fake-graphical-session = {
    Unit = {
      Description = "Stand-in for the NixOS graphical-session hook";
      BindsTo = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
  };
}
