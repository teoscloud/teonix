#!/bin/bash

CONFIG_FILE="/home/teodor/.config/hypr/hyprland.conf"
SEARCH_LINE="monitor = eDP-1, 2880x1800@60, 0x0, "
CURRENT_SCALE=$(grep -oP "$SEARCH_LINE\K\d+\.?\d*" "$CONFIG_FILE")

if [ "$CURRENT_SCALE" == "1" ]; then
    sed -i "s/${SEARCH_LINE}1,/${SEARCH_LINE}1.6666,/" "$CONFIG_FILE"
elif [ "$CURRENT_SCALE" == "1.6666" ]; then
    sed -i "s/${SEARCH_LINE}1.6666,/${SEARCH_LINE}1,/" "$CONFIG_FILE"
else
    echo "No matching scale found or wrong format"
fi
