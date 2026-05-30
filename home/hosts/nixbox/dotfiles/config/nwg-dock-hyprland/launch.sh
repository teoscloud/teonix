#!/usr/bin/env bash
# nwg-dock-hyprland for nixbox: reserved bottom space (-x), always visible (-r).
# -x sets a layer-shell exclusive zone so tiled/scrolling windows stop above the dock.

config_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
cd "$config_dir" || exit 1

exec nwg-dock-hyprland \
  -x \
  -r \
  -p bottom \
  -a center \
  -i 64 \
  -mb 10 \
  -s style.css \
  -nolauncher \
  -g '"waybar,swaync-control-center,gtk-layer-shell,xdg-desktop-portal-gtk,org.gnome.NautilusPreviewer,easyeffects"'
