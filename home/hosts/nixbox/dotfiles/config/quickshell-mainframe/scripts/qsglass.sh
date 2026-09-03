#!/usr/bin/env bash
# Restore glass Quickshell + rounded Hyprland decoration.
# Always replace any running Quickshell — never stack instances.
set -euo pipefail
ROOT="$HOME/teonix/home/hosts/nixbox/dotfiles/config"
GLASS="$ROOT/quickshell"
KILL="$ROOT/quickshell-mainframe/scripts/qs-kill-all.sh"

if command -v hyprctl >/dev/null; then
  hyprctl --batch "\
keyword decoration:rounding 10;\
keyword decoration:rounding_power 2;\
keyword decoration:shadow:enabled true;\
keyword decoration:blur:enabled true;\
keyword general:border_size 1;\
keyword general:col.active_border rgba(141417ee) rgba(FFFFFFFFee) 45deg;\
keyword general:col.inactive_border rgba(595959aa);\
keyword bezier linear,0,0,1,1;\
keyword animation borderangle,1,30,linear,loop;\
keyword animation windows,1,7,default;\
keyword animation windowsOut,1,7,default,popin 80%" >/dev/null 2>&1 || true
fi

bash "$KILL"
bash "$ROOT/quickshell-mainframe/scripts/qs-live-ipc.sh" --install-binds || true

exec qs -p "$GLASS" -d
