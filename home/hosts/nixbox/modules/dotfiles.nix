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
  home.file.".config/hypr/listentomb.sh".source = "${dotfilesPath}/config/hypr/listentomb.sh";

  # ✅ Symlink other application configurations
  home.file.".config/kitty/kitty.conf".source = "${dotfilesPath}/config/kitty/kitty.conf";
  home.file.".config/nwg-look/config".source = "${dotfilesPath}/config/nwg-look/config";
  home.file.".config/rofi/config.rasi".source = "${dotfilesPath}/config/rofi/config.rasi";
  home.file.".config/rofi/rounded-common.rasi".source = "${dotfilesPath}/config/rofi/rounded-common.rasi";
  home.file.".config/waybar/config".source = "${dotfilesPath}/config/waybar/config";
  home.file.".config/waybar/style.css".source = "${dotfilesPath}/config/waybar/style.css";
  home.file.".config/wofi/config".source = "${dotfilesPath}/config/wofi/config";
  home.file.".config/wofi/style.css".source = "${dotfilesPath}/config/wofi/style.css";

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
