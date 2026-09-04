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
      if [[ ! -x /usr/bin/steam ]]; then
        echo "Fedora Asahi Steam is not installed." >&2
        echo "  bash ~/teonix/hosts/applenix/fedora.sh steam" >&2
        exit 1
      fi

      # /usr/bin/steam is Fedora python + PyQt6 splash, then muvm/FEX.
      # The Hyprland session exports Nix QT_PLUGIN_PATH / Mesa paths so Nix
      # Qt apps work. Fedora Qt then loads Nix wayland plugins against host
      # libQt6 and aborts in QGuiApplicationPrivate::createPlatformIntegration.
      # Unset those for this process only — do not put /usr/lib64 on
      # LD_LIBRARY_PATH (that leaks into Hyprland and kills libexpat).
      unset QT_PLUGIN_PATH
      unset QT_PLUGIN_PATH_1
      unset QML2_IMPORT_PATH
      unset QML_IMPORT_PATH
      unset QTWEBENGINEPROCESS_PATH
      unset QT_QPA_PLATFORM_PLUGIN_PATH
      unset QT_QPA_PLATFORMTHEME
      unset LIBGL_DRIVERS_PATH
      unset GBM_BACKENDS_PATH
      unset __EGL_VENDOR_LIBRARY_FILENAMES
      unset LD_LIBRARY_PATH

      # muvm / FEXBash must be the Fedora ones, not a Nix shadow.
      export PATH="/usr/bin:/usr/sbin''${PATH:+:$PATH}"

      # A second muvm/Steam pair makes the client tear down and relaunch.
      # steam:// from the guest also hits the host handler and used to do that.
      if pgrep -f '/usr/bin/muvm.*bin_steam\.sh' >/dev/null \
        || pgrep -f '/usr/bin/python3 /usr/bin/steam' >/dev/null; then
        echo "Steam is already running — not starting another muvm." >&2
        exit 0
      fi

      # After first bootstrap, skip the PyQt splash. Its window probe still
      # looks for "Steam Big" / steamwebhelper titles that current Steam
      # does not use; closing the splash then SIGTERMs the guest.
      launcher="$HOME/.local/share/fex-steam/steam-launcher/bin_steam.sh"
      if [[ -f $launcher ]] && command -v muvm >/dev/null && command -v FEXBash >/dev/null; then
        cmd=$(printf '%q ' "$launcher" -cef-force-occlusion "$@")
        exec muvm -- FEXBash -c "$cmd"
      fi

      exec /usr/bin/steam "$@"
    '';
  };

  steamHost = pkgs.writeShellApplication {
    name = "steam";
    text = ''
      exec ${teonixSteam}/bin/teonix-steam "$@"
    '';
  };

  teonixSteamAdd = pkgs.writeShellApplication {
    name = "teonix-steam-add";
    runtimeInputs = [ pkgs.python3 ];
    text = ''
      exec python3 ${./../scripts/teonix-steam-add.py} "$@"
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
    STEAM_EXTRA_COMPAT_TOOLS_PATHS = "/home/${username}/.steam/root/compatibilitytools.d";
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
    teonixSteamAdd
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
    exec = "teonix-steam %U";
    icon = "steam";
    terminal = false;
    categories = [ "Game" ];
  };

  # Steam's Browse button cannot open a host file picker from inside muvm.
  # A .desktop here shows up in "Add a Non-Steam Game" so you can tick it.
  xdg.desktopEntries.battle-net-setup = {
    name = "Battle.net Setup";
    comment = "Windows Battle.net installer — add from Steam without Browse";
    exec = "${config.home.homeDirectory}/Downloads/Battle.net-Setup.exe";
    icon = "applications-games";
    terminal = false;
    categories = [ "Game" ];
  };

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
