{ config, pkgs, lib, ... }:

let
  dotfilesPath = ../dotfiles;

  # code-cursor only installs 1024x1024; GTK menus then blow up.
  cursorIconSrc = "${pkgs.code-cursor}/share/icons/hicolor/1024x1024/apps/cursor.png";
  cursorIconSizes = [ 16 22 24 32 48 64 128 256 ];
  cursorHicolorIcons = pkgs.runCommand "cursor-hicolor-menu-icons" {
    nativeBuildInputs = [ pkgs.imagemagick ];
  } ''
    for size in ${lib.concatStringsSep " " (map toString cursorIconSizes)}; do
      mkdir -p "$out/hicolor/''${size}x''${size}/apps"
      magick ${cursorIconSrc} -resize "''${size}x''${size}" \
        "$out/hicolor/''${size}x''${size}/apps/cursor.png"
    done
  '';
  cursorHicolorIconFiles = lib.listToAttrs (map (size: {
    name = "icons/hicolor/${toString size}x${toString size}/apps/cursor.png";
    value = {
      source = "${cursorHicolorIcons}/hicolor/${toString size}x${toString size}/apps/cursor.png";
    };
  }) cursorIconSizes);
in {
  # ✅ Symlink shell dotfiles
  home.file.".zshrc" = {
    source = "${dotfilesPath}/shell/.zshrc";
    force = true;
  };
  home.file.".p10k.zsh" = {
    source = "${dotfilesPath}/shell/.p10k.zsh";
    force = true;
  };

  # ✅ Symlink Hyprland configurations
  home.file.".config/hypr/hyprland.conf".source = "${dotfilesPath}/config/hypr/hyprland.conf";
  home.file.".config/hyprflow/config.toml".source = "${dotfilesPath}/config/hyprflow/config.toml";
  home.file.".config/hypr/hyprlock.conf".source = "${dotfilesPath}/config/hypr/hyprlock.conf";
  home.file.".config/hypr/hyprpaper.conf".source = "${dotfilesPath}/config/hypr/hyprpaper.conf";
  home.file.".config/hypr/hypridle.conf".source = "${dotfilesPath}/config/hypr/hypridle.conf";

  # ✅ Hyprland scripts
  home.file.".config/hypr/cyclemon.sh".source = "${dotfilesPath}/config/hypr/cyclemon.sh";
  home.file.".config/hypr/listentomb.sh".source = "${dotfilesPath}/config/hypr/listentomb.sh";
  home.file.".config/hypr/scripts/install-whitesur-system-icons.sh".source =
    "${dotfilesPath}/config/hypr/scripts/install-whitesur-system-icons.sh";

  home.activation.whitesurSystemIcons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    PATH="${pkgs.python3}/bin:$PATH" \
      bash ${dotfilesPath}/config/hypr/scripts/install-whitesur-system-icons.sh
  '';

  # ✅ Symlink other application configurations
  home.file.".config/kitty/kitty.conf".source = "${dotfilesPath}/config/kitty/kitty.conf";
  home.file.".config/nwg-look/config".source = "${dotfilesPath}/config/nwg-look/config";
  home.file.".config/rofi/config.rasi".source = "${dotfilesPath}/config/rofi/config.rasi";
  home.file.".config/rofi/rounded-common.rasi".source = "${dotfilesPath}/config/rofi/rounded-common.rasi";
  home.file.".config/waybar/config".source = "${dotfilesPath}/config/waybar/config";
  home.file.".config/waybar/style.css".source = "${dotfilesPath}/config/waybar/style.css";
  home.file.".config/wofi/config".source = "${dotfilesPath}/config/wofi/config";
  home.file.".config/wofi/style.css".source = "${dotfilesPath}/config/wofi/style.css";

  # Quickshell — live out-of-store symlink so `qs -r` picks up edits without HM rebuild
  home.file.".config/quickshell".source = config.lib.file.mkOutOfStoreSymlink
    "${config.home.homeDirectory}/teonix/home/hosts/nixbox/dotfiles/config/quickshell";

  # Equibop / Equicord — live out-of-store so CSS edits apply without HM rebuild.
  # Activation keeps the theme in enabledThemes after Equibop updates.
  home.file.".config/equibop/themes/qsmainframe.theme.css" = {
    source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/teonix/home/hosts/nixbox/dotfiles/config/equibop/themes/qsmainframe.theme.css";
    force = true;
  };

  home.activation.equibopMainframeTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    settings="$HOME/.config/equibop/settings/settings.json"
    if [ -f "$settings" ]; then
      ${pkgs.jq}/bin/jq '
        .enabledThemes |= (
          if type == "array" then
            if index("qsmainframe.theme.css") then . else . + ["qsmainframe.theme.css"] end
          else ["qsmainframe.theme.css"] end
        )
      ' "$settings" > "$settings.tmp" && mv "$settings.tmp" "$settings"
    fi
  '';

  # Smaller cursor icons for GTK menus (app launchers, etc.)
  xdg.dataFile = cursorHicolorIconFiles;

  home.activation.updateUserHicolorIconCache = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -d "$HOME/.local/share/icons/hicolor" ] && command -v gtk-update-icon-cache >/dev/null; then
      gtk-update-icon-cache -f -t "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
    fi
  '';

  # ✅ wlogout configuration
  home.file.".config/wlogout/hibernate-hover.png".source = "${dotfilesPath}/config/wlogout/hibernate-hover.png";
  home.file.".config/wlogout/hibernate.png".source = "${dotfilesPath}/config/wlogout/hibernate.png";
  home.file.".config/wlogout/layout".source = "${dotfilesPath}/config/wlogout/layout";
  home.file.".config/wlogout/lock-hover.png".source = "${dotfilesPath}/config/wlogout/lock-hover.png";
  home.file.".config/wlogout/lock.png".source = "${dotfilesPath}/config/wlogout/lock.png";
  home.file.".config/wlogout/logout-hover.png".source = "${dotfilesPath}/config/wlogout/logout-hover.png";
  home.file.".config/wlogout/logout.png".source = "${dotfilesPath}/config/wlogout/logout.png";
  home.file.".config/wlogout/power-hover.png".source = "${dotfilesPath}/config/wlogout/power-hover.png";
  home.file.".config/wlogout/power.png".source = "${dotfilesPath}/config/wlogout/power.png";
  home.file.".config/wlogout/restart-hover.png".source = "${dotfilesPath}/config/wlogout/restart-hover.png";
  home.file.".config/wlogout/restart.png".source = "${dotfilesPath}/config/wlogout/restart.png";
  home.file.".config/wlogout/sleep-hover.png".source = "${dotfilesPath}/config/wlogout/sleep-hover.png";
  home.file.".config/wlogout/sleep.png".source = "${dotfilesPath}/config/wlogout/sleep.png";
  home.file.".config/wlogout/style.css".source = "${dotfilesPath}/config/wlogout/style.css";



  # ✅ Wallpapers
  home.file.".config/hypr/wallpapers/cloudy.jpg".source = "${dotfilesPath}/config/hypr/wallpapers/cloudy.jpg";
  home.file.".config/hypr/wallpapers/darkmountain.jpg".source = "${dotfilesPath}/config/hypr/wallpapers/darkmountain.jpg";
  home.file.".config/hypr/wallpapers/pinkfield.jpg".source = "${dotfilesPath}/config/hypr/wallpapers/pinkfield.jpg";
  home.file.".config/hypr/wallpapers/re8.png".source = "${dotfilesPath}/config/hypr/wallpapers/re8.png";
  home.file.".config/hypr/wallpapers/lightpurple.jpg".source = "${dotfilesPath}/config/hypr/wallpapers/lightpurple.jpg";
  home.file.".config/hypr/wallpapers/purplefloral.jpg".source = "${dotfilesPath}/config/hypr/wallpapers/purplefloral.jpg";
  home.file.".config/hypr/wallpapers/flowie.jpg".source = "${dotfilesPath}/config/hypr/wallpapers/flowie.jpg";
  home.file.".config/hypr/wallpapers/blisslsd.png".source = "${dotfilesPath}/config/hypr/wallpapers/blisslsd.png";
  home.file.".config/hypr/wallpapers/brancastle.jpg".source = "${dotfilesPath}/config/hypr/wallpapers/brancastle.jpg";
  # ✅ Scripts
  home.file.".config/hypr/scripts/cssbackup.css".source = "${dotfilesPath}/config/hypr/scripts/cssbackup.css";
  home.file.".config/hypr/scripts/mediaplayer.py".source = "${dotfilesPath}/config/hypr/scripts/mediaplayer.py";
  home.file.".config/hypr/scripts/waybar-wttr.py".source = "${dotfilesPath}/config/hypr/scripts/waybar-wttr.py";
  home.file.".config/hypr/scripts/weather.py".source = "${dotfilesPath}/config/hypr/scripts/weather.py";
  home.file.".config/hypr/scripts/audio-transmit.sh" = {
    source = "${dotfilesPath}/config/hypr/scripts/audio-transmit.sh";
    executable = true;
  };
  home.file.".config/hypr/scripts/udp-send-chunked.py" = {
    source = "${dotfilesPath}/config/hypr/scripts/udp-send-chunked.py";
    executable = true;
  };
  home.file.".config/hypr/scripts/audio-transmit-toggle.sh" = {
    source = "${dotfilesPath}/config/hypr/scripts/audio-transmit-toggle.sh";
    executable = true;
  };
  home.file.".config/hypr/scripts/scrolling-promote-new-window.sh" = {
    source = "${dotfilesPath}/config/hypr/scripts/scrolling-promote-new-window.sh";
    executable = true;
  };
  home.file.".config/hypr/scripts/ro-type.sh" = {
    source = "${dotfilesPath}/config/hypr/scripts/ro-type.sh";
    executable = true;
  };
  home.file.".config/hypr/scripts/hyprflow-restore-on-login.sh" = {
    source = "${dotfilesPath}/config/hypr/scripts/hyprflow-restore-on-login.sh";
    executable = true;
  };
  # ✅ Symlink ios font config
  home.file.".config/fontconfig/fonts.conf".source = "${dotfilesPath}/config/fontconfig/fonts.conf";
  home.file.".config/fontconfig/conf.d/50-michroma.conf".source = "${dotfilesPath}/config/fontconfig/conf.d/50-michroma.conf";

  # ✅ Weather API (Only if present)
  #home.file.".config/hypr/scripts/secrets/weather_api_key.txt".source = "${dotfilesPath}/config/hypr/scripts/secrets/weather_api_key.txt";
}
