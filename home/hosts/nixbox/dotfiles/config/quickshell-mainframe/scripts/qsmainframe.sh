#!/usr/bin/env bash
# Switch to White Mainframe Quickshell + Hyprland decoration.
# Always replace any running Quickshell — never stack instances.
set -euo pipefail
MF="$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe"
DEC="$HOME/teonix/home/hosts/nixbox/dotfiles/config/hypr/mainframe-decoration.conf"
KILL="$MF/scripts/qs-kill-all.sh"

if [[ -f "$DEC" ]] && command -v hyprctl >/dev/null; then
  hyprctl --batch "\
keyword decoration:rounding 9;\
keyword decoration:rounding_power 1;\
keyword decoration:shadow:enabled false;\
keyword decoration:blur:enabled false;\
keyword general:border_size 1;\
keyword general:col.active_border rgba(2a2e34ee) rgba(fffffff0) 45deg;\
keyword general:col.inactive_border rgba(9aa0a8aa);\
keyword bezier linear,0,0,1,1;\
keyword animation borderangle,1,22,linear,loop;\
keyword animation windowsIn,1,4,default,popin 55%;\
keyword animation windowsOut,1,3,default,popin 55%" >/dev/null 2>&1 || true
fi

bash "$KILL"
bash "$MF/scripts/qs-live-ipc.sh" --install-binds || true

# Prefer ~/.config/quickshell when HM already points it at mainframe, so
# plain `qs ipc` (and live-ipc) both find this instance. Fall back to -p $MF.
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
# Do not pass --no-duplicate: if a leftover survived, -n exits and leaves the old shell.
if [[ -e $CFG ]] && [[ $(readlink -f "$CFG") == $(readlink -f "$MF") ]]; then
  exec qs -p "$CFG" -d
fi
exec qs -p "$MF" -d
