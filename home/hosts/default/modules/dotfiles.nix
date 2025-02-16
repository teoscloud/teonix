{ config, ... }:

let
  dotfilesPath = ../dotfiles;  # Adjusted path for nixbox
in {
  # ✅ Symlink shell dotfiles
  home.file.".zshrc".source = "${dotfilesPath}/shell/.zshrc";
  home.file.".p10k.zsh".source = "${dotfilesPath}/shell/.p10k.zsh";

  # ✅ Symlink Hyprland configurations
  home.file.".config/hypr/hyprland.conf".source = "${dotfilesPath}/config/hypr/hyprland.conf";
  home.file.".config/hypr/hyprlock.conf".source = "${dotfilesPath}/config/hypr/hyprlock.conf";
  home.file.".config/hypr/hyprpaper.conf".source = "${dotfilesPath}/config/hypr/hyprpaper.conf";
  home.file.".config/hypr/hypridle.conf".source = "${dotfilesPath}/config/hypr/hypridle.conf";

  # ✅ Hyprland scripts
  home.file.".config/hypr/cyclemon.sh".source = "${dotfilesPath}/config/hypr/cyclemon.sh";

  # ✅ Symlink other application configurations
  home.file.".config/kitty/kitty.conf".source = "${dotfilesPath}/config/kitty/kitty.conf";
  home.file.".config/nwg-look/config".source = "${dotfilesPath}/config/nwg-look/config";
  home.file.".config/rofi/config.rasi".source = "${dotfilesPath}/config/rofi/config.rasi";
  home.file.".config/rofi/rounded-common.rasi".source = "${dotfilesPath}/config/rofi/rounded-common.rasi";
  home.file.".config/waybar/config".source = "${dotfilesPath}/config/waybar/config";
  home.file.".config/waybar/style.css".source = "${dotfilesPath}/config/waybar/style.css";
  home.file.".config/wofi/config".source = "${dotfilesPath}/config/wofi/config";
  home.file.".config/wofi/style.css".source = "${dotfilesPath}/config/wofi/style.css";

  # ✅ Wallpapers
  home.file.".config/hypr/wallpapers/cloudy.jpg".source = "${dotfilesPath}/config/hypr/wallpapers/cloudy.jpg";
  home.file.".config/hypr/wallpapers/darkmountain.jpg".source = "${dotfilesPath}/config/hypr/wallpapers/darkmountain.jpg";
  home.file.".config/hypr/wallpapers/pinkfield.jpg".source = "${dotfilesPath}/config/hypr/wallpapers/pinkfield.jpg";
  home.file.".config/hypr/wallpapers/re8.png".source = "${dotfilesPath}/config/hypr/wallpapers/re8.png";

  # ✅ Scripts
  home.file.".config/hypr/scripts/cssbackup.css".source = "${dotfilesPath}/config/hypr/scripts/cssbackup.css";
  home.file.".config/hypr/scripts/mediaplayer.py".source = "${dotfilesPath}/config/hypr/scripts/mediaplayer.py";
  home.file.".config/hypr/scripts/waybar-wttr.py".source = "${dotfilesPath}/config/hypr/scripts/waybar-wttr.py";
  home.file.".config/hypr/scripts/weather.py".source = "${dotfilesPath}/config/hypr/scripts/weather.py";

  # ✅ Symlink ios font config
  home.file.".config/fontconfig/fonts.conf".source = "${dotfilesPath}/config/fontconfig/fonts.conf";

  # ✅ Weather API (Only if present)
  #home.file.".config/hypr/scripts/secrets/weather_api_key.txt".source = "${dotfilesPath}/config/hypr/scripts/secrets/weather_api_key.txt";
}
