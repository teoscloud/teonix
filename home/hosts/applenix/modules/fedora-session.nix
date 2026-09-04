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

  # GPU on Fedora: Nix Mesa is what Nix apps must use. Upstream Mesa ships the
  # Asahi gallium driver, so Nix Hyprland/kitty get hardware GL (Mesa 4.6) from
  # it — Fedora's copies are never needed. Putting /usr/lib64 on
  # LD_LIBRARY_PATH is actively harmful: the Nix loader then picks host libEGL,
  # which cannot resolve Nix libexpat, and Hyprland dies before the first frame.
  #
  # The supported mechanism is targets.genericLinux.gpu (enabled by default
  # here): `sudo non-nixos-gpu-setup` symlinks /run/opengl-driver at the driver
  # env below, which Nix libglvnd/Mesa search with no env vars at all.
  # fedora.sh's `gpu` step runs it. These exports are the belt-and-braces path
  # for the compositor, so the session also works before that step has run and
  # stays pinned to the drivers of the *current* generation.
  gpuDrivers = config.targets.genericLinux.gpu.drivers;

  gpuDriverExports = ''
    export LIBGL_DRIVERS_PATH="${gpuDrivers}/lib/dri"
    export GBM_BACKENDS_PATH="${gpuDrivers}/lib/gbm"
    export __EGL_VENDOR_LIBRARY_FILENAMES="${gpuDrivers}/share/glvnd/egl_vendor.d/50_mesa.json"
  '';

  hyprlandNixSession = pkgs.writeShellScriptBin "hyprland-nix-session" ''
    log="''${XDG_STATE_HOME:-$HOME/.local/state}/hyprland-nix-session.log"
    mkdir -p "$(dirname "$log")"
    exec >>"$log" 2>&1
    echo "==== $(date -Iseconds) pid=$$ user=$USER ===="

    # hm-session-vars.sh appends $XCURSOR_PATH / $TERM. SDDM sets neither, and
    # under `set -u` that aborts the script — black screen, Hyprland never execs.
    set +u
    for f in \
      "$HOME/.nix-profile/etc/profile.d/hm-session-vars.sh" \
      "/etc/profiles/per-user/''${USER:-}/etc/profile.d/hm-session-vars.sh" \
      /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    do
      [ -f "$f" ] && . "$f"
    done

    ${gpuDriverExports}

    export XDG_CURRENT_DESKTOP=Hyprland
    export XDG_SESSION_DESKTOP=Hyprland
    export XDG_SESSION_TYPE=wayland
    export WLR_NO_HARDWARE_CURSORS="''${WLR_NO_HARDWARE_CURSORS:-1}"

    # start-hyprland refuses to run off NixOS unless nixGL is installed, so the
    # greeter gets Hyprland directly (its watchdog is a nicety, not a need).
    echo "Hyprland=${pkgs.hyprland}/bin/Hyprland"
    echo "drivers=${gpuDrivers}"
    echo "run-opengl-driver=$(readlink /run/opengl-driver || echo '<unset: run fedora.sh gpu step>')"
    echo "LIBGL_DRIVERS_PATH=''${LIBGL_DRIVERS_PATH:-}"
    echo "GBM_BACKENDS_PATH=''${GBM_BACKENDS_PATH:-}"
    echo "exec Hyprland"

    # Secret Service before any client: drop leftover ksecretd, join PAM
    # gnome-keyring (or start one). See fedora-secrets.nix.
    if [ -x "$HOME/.nix-profile/bin/teonix-secrets-ensure" ]; then
      "$HOME/.nix-profile/bin/teonix-secrets-ensure" || true
    fi

    # Hyprland writes a stub hyprland.conf (and the deprecation banner) if
    # that file is missing, even when hyprland.lua is present.
    rm -f "$HOME/.config/hypr/hyprland.conf"

    exec ${pkgs.hyprland}/bin/Hyprland -c "$HOME/.config/hypr/hyprland.lua" "$@"
  '';

  # Fedora Asahi's /usr/bin/steam is a muvm+FEX wrapper, not the client.
  # Nixpkgs Steam is x86-only and must never land on this PATH.
  teonixSteam = pkgs.writeShellApplication {
    name = "teonix-steam";
    text = ''
      exec ${./../scripts/teonix-steam.sh} "$@"
    '';
  };

  steamHost = pkgs.writeShellApplication {
    name = "steam";
    text = ''
      exec ${./../scripts/teonix-steam.sh} "$@"
    '';
  };

  teonixSteamKill = pkgs.writeShellApplication {
    name = "teonix-steam-kill";
    text = ''
      exec ${./../scripts/teonix-steam-kill.sh} "$@"
    '';
  };

  teonixSteamAdd = pkgs.writeShellApplication {
    name = "teonix-steam-add";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./../scripts/teonix-steam-add.py} "$@"
    '';
  };

  teonixBattlenet = pkgs.writeShellApplication {
    name = "teonix-battlenet";
    text = ''
      exec ${./../scripts/teonix-battlenet.sh} "$@"
    '';
  };

  teonixBattlenetKill = pkgs.writeShellApplication {
    name = "teonix-battlenet-kill";
    text = ''
      exec ${./../scripts/teonix-battlenet-kill.sh} "$@"
    '';
  };
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
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "${pkgs.proton-ge-bin.steamcompattool}:/home/${username}/.steam/root/compatibilitytools.d";
    RUST_MIN_STACK = "16777216";
  };

  # Drop the abandoned "link Fedora's libEGL into a wrap dir" experiment.
  home.activation.removeStaleHostGlWrap = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -rf "$HOME/.local/share/teonix/host-gl"
  '';

  # NixOS-only extras: compositor and portals live in programs.* there.
  home.packages = [
    hyprlandNixSession
    teonixSteam
    steamHost
    teonixSteamKill
    teonixSteamAdd
    teonixBattlenet
    teonixBattlenetKill
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

  xdg.desktopEntries.steam = {
    name = "Steam";
    comment = "Fedora Asahi Steam (muvm + FEX)";
    exec = "teonix-steam";
    icon = "steam";
    terminal = false;
    categories = [ "Game" ];
  };

  # GloriousEggroll ships an aarch64 GE-Proton tarball; nixpkgs proton-ge-bin
  # picks that on this host. Lutris (umu) and Steam both look here.
  xdg.dataFile."lutris/runners/proton/GE-Proton".source = pkgs.proton-ge-bin.steamcompattool;
  xdg.dataFile."Steam/compatibilitytools.d/GE-Proton".source = pkgs.proton-ge-bin.steamcompattool;

  # One launcher. teonix-battlenet runs setup on first launch, then the client.
  # Do not ship a separate Setup.desktop — leftover installer entries are removed
  # after a successful install.
  xdg.desktopEntries.battlenet = {
    name = "Battle.net";
    comment = "Blizzard Battle.net (muvm + FEX, no Steam)";
    exec = "teonix-battlenet";
    icon = "applications-games";
    terminal = false;
    categories = [ "Game" ];
    settings.StartupWMClass = "steam_app_battlenet";
  };

  home.activation.removeStaleBattlenetSetupDesktop = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    rm -f "$HOME/.local/share/applications/battle-net-setup.desktop" \
          "$HOME/.local/share/applications/Battle.net Setup.desktop"
  '';

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
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
      common = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
      };
    };
  };

  # Stable Exec path — not a /nix/store hash. fedora.sh installs a trampoline
  # at /usr/local/bin/hyprland-nix-session that execs the current HM generation.
  # Greeter entries therefore never need to be recopied after updatehome.
  xdg.dataFile."wayland-sessions/hyprland-nix.desktop".text = ''
    [Desktop Entry]
    Name=Hyprland (Nix)
    Comment=Hyprland from teonix Home Manager
    Exec=/usr/local/bin/hyprland-nix-session
    TryExec=/usr/local/bin/hyprland-nix-session
    Type=Application
    DesktopNames=Hyprland
  '';
  xdg.dataFile."wayland-sessions/hyprland.desktop".text = ''
    [Desktop Entry]
    Name=Hyprland (Nix)
    Comment=Hyprland from teonix Home Manager — do not use Fedora's bare Hyprland
    Exec=/usr/local/bin/hyprland-nix-session
    TryExec=/usr/local/bin/hyprland-nix-session
    Type=Application
    DesktopNames=Hyprland
  '';

  home.activation.installHyprlandSessionTrampoline = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    trampoline=/usr/local/bin/hyprland-nix-session
    session_dir=/usr/local/share/wayland-sessions
    src="$HOME/.local/share/wayland-sessions"

    write_trampoline() {
      local dest=$1
      mkdir -p "$(dirname "$dest")"
      cat >"$dest" <<'TRAMPOLINE'
    #!/bin/sh
    for c in \
      "$HOME/.nix-profile/bin/hyprland-nix-session" \
      "/etc/profiles/per-user/$USER/bin/hyprland-nix-session"
    do
      if [ -x "$c" ]; then
        exec "$c" "$@"
      fi
    done
    echo "hyprland-nix-session not in the Home Manager profile — run updatehome" >&2
    exit 1
    TRAMPOLINE
      chmod 755 "$dest"
    }

    if [ -w /usr/local/bin ] || [ -w "$trampoline" ]; then
      write_trampoline "$trampoline"
    fi
    if [ -d "$session_dir" ] && [ -w "$session_dir" ]; then
      [ -f "$src/hyprland-nix.desktop" ] && cp -f "$src/hyprland-nix.desktop" "$session_dir/"
      [ -f "$src/hyprland.desktop" ] && cp -f "$src/hyprland.desktop" "$session_dir/"
    fi
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
