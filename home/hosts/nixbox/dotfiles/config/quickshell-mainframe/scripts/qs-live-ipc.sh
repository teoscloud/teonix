#!/usr/bin/env bash
# Call IPC on the Quickshell that is actually running (mainframe -p or glass default).
# `qs ipc` without -p always targets ~/.config/quickshell, so it misses a -p instance
# started with the absolute mainframe path (e.g. qsmainframe.sh).
set -euo pipefail
MF="$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe"
GLASS="$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
SELF="$MF/scripts/qs-live-ipc.sh"

# Runtime rebind: live hyprland.lua is a Home Manager store symlink until updatehome.
if [[ "${1:-}" == "--install-binds" ]]; then
  command -v hyprctl >/dev/null || exit 0
  ipc="bash $SELF"
  # Lua config: binds are (re)registered through `hyprctl eval`. Key strings
  # must match hyprland.lua exactly for hl.unbind to hit.
  hyprctl eval "
    hl.unbind('SUPER + SPACE') hl.unbind('SUPER + period') hl.unbind('SUPER + O') hl.unbind('SUPER + N')
    hl.bind('SUPER + SPACE', hl.dsp.exec_cmd('$ipc launcher toggle'))
    hl.bind('SUPER + period', hl.dsp.exec_cmd('$ipc emoji toggle'))
    hl.bind('SUPER + O', hl.dsp.exec_cmd('$ipc power toggle'))
    hl.bind('SUPER + N', hl.dsp.exec_cmd('$ipc notifs toggle'))
  " >/dev/null
  exit 0
fi

for root in "$MF" "$CFG" "$GLASS"; do
  if qs -p "$root" ipc show >/dev/null 2>&1; then
    exec qs -p "$root" ipc call "$@"
  fi
done
exec qs ipc call "$@"
