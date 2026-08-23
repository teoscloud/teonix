#!/usr/bin/env bash
# On new window: promote, then resize first column to 0.66 (layout leaves it at 0.5 after split), then ensure new column is 0.66
[[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]] && exit 0
SOCK="$XDG_RUNTIME_DIR/hypr/${HYPRLAND_INSTANCE_SIGNATURE}/.socket2.sock"
while read -r line; do
  case "$line" in
    openwindow*)
      sleep 0.06
      hyprctl dispatch layoutmsg promote
      sleep 0.12
      # First column (left): focus it and set to 0.66
      hyprctl dispatch layoutmsg focus l
      sleep 0.08
      hyprctl dispatch layoutmsg colresize 0.66
      sleep 0.05
      # Back to new window and set its column to 0.66
      hyprctl dispatch layoutmsg focus r
      sleep 0.05
      hyprctl dispatch layoutmsg colresize 0.66
      # Force all columns to 0.66 in case the layout ignored the first column
      sleep 0.03
      hyprctl dispatch layoutmsg colresize all 0.66
      ;;
  esac
done < <(socat -U - "UNIX-CONNECT:$SOCK")
