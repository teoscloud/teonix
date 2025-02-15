{ config, ... }:

{
  # ✅ Symlink shell dotfiles
  home.file.".zshrc".source = ../dotfiles/shell/.zshrc;
  home.file.".p10k.zsh".source = ../dotfiles/shell/.p10k.zsh;

  # ✅ Symlink configurations inside ~/.config/
  home.file.".config/hypr/hyprland.conf".source = ../dotfiles/config/hypr/hyprland.conf;
  home.file.".config/hypr/hyprlock.conf".source = ../dotfiles/config/hypr/hyprlock.conf;
  home.file.".config/hypr/hyprpaper.conf".source = ../dotfiles/config/hypr/hyprpaper.conf;
  home.file.".config/hypr/hypridle.conf".source = ../dotfiles/config/hypr/hypridle.conf;

  # hyprland scripts: 
  home.file.".config/hypr/cyclemon.sh".source = ../dotfiles/config/hypr/cyclemon.sh;


  home.file.".config/kitty/kitty.conf".source = ../dotfiles/config/kitty/kitty.conf;
  home.file.".config/nwg-look/config".source = ../dotfiles/config/nwg-look/config;
  home.file.".config/rofi/config.rasi".source = ../dotfiles/config/rofi/config.rasi;
  home.file.".config/rofi/rounded-common.rasi".source = ../dotfiles/config/rofi/rounded-common.rasi;
  home.file.".config/waybar/config".source = ../dotfiles/config/waybar/config;
  home.file.".config/waybar/style.css".source = ../dotfiles/config/waybar/style.css;
  home.file.".config/wofi/config".source = ../dotfiles/config/wofi/config;
  home.file.".config/wofi/style.css".source = ../dotfiles/config/wofi/style.css;

  # ✅ Symlink wallpapers
  home.file.".config/hypr/wallpapers/cloudy.jpg".source = ../dotfiles/config/hypr/wallpapers/cloudy.jpg;
  home.file.".config/hypr/wallpapers/darkmountain.jpg".source = ../dotfiles/config/hypr/wallpapers/darkmountain.jpg;
  home.file.".config/hypr/wallpapers/pinkfield.jpg".source = ../dotfiles/config/hypr/wallpapers/pinkfield.jpg;
  home.file.".config/hypr/wallpapers/re8.png".source = ../dotfiles/config/hypr/wallpapers/re8.png;

  # ✅ Symlink scripts
  home.file.".config/hypr/scripts/cssbackup.css".source = ../dotfiles/config/hypr/scripts/cssbackup.css;
  home.file.".config/hypr/scripts/mediaplayer.py".source = ../dotfiles/config/hypr/scripts/mediaplayer.py;
  home.file.".config/hypr/scripts/waybar-wttr.py".source = ../dotfiles/config/hypr/scripts/waybar-wttr.py;
  home.file.".config/hypr/scripts/weather.py".source = ../dotfiles/config/hypr/scripts/weather.py;

  # weather api:
  home.file.".config/hypr/scripts/secrets/weather_api_key.txt".source = ../dotfiles/config/hypr/scripts/secrets/weather_api_key.txt;

  # ✅ Symlink ios font config /home/teodor/myprojects/teonix/home/dotfiles/config/fontconfig/fonts.conf
  home.file.".config/fontconfig/fonts.conf".source = ../dotfiles/config/fontconfig/fonts.conf;
}
