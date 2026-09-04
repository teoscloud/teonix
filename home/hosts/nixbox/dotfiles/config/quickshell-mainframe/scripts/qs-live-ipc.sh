#!/usr/bin/env bash
# Call IPC on the Quickshell that is actually running (mainframe -p or glass default).
# `qs ipc` without -p always targets ~/.config/quickshell, so it misses a -p instance
# started with the absolute mainframe path (e.g. qsmainframe.sh).
set -euo pipefail
MF="$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe"
GLASS="$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell"
CFG="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
SELF="$MF/scripts/qs-live-ipc.sh"

# Runtime rebind: live hyprland.conf is a Home Manager store symlink until updatehome.
if [[ "${1:-}" == "--install-binds" ]]; then
  command -v hyprctl >/dev/null || exit 0
  ipc="bash $SELF"
  hyprctl keyword unbind 'SUPER, SPACE' >/dev/null 2>&1 || true
  hyprctl keyword unbind 'SUPER, period' >/dev/null 2>&1 || true
  hyprctl keyword unbind 'SUPER, O' >/dev/null 2>&1 || true
  hyprctl keyword unbind 'SUPER, N' >/dev/null 2>&1 || true
  hyprctl keyword bind "SUPER, SPACE, exec, $ipc launcher toggle" >/dev/null
  hyprctl keyword bind "SUPER, period, exec, $ipc emoji toggle" >/dev/null
  hyprctl keyword bind "SUPER, O, exec, $ipc power toggle" >/dev/null
  hyprctl keyword bind "SUPER, N, exec, $ipc notifs toggle" >/dev/null
  exit 0
fi

for root in "$MF" "$CFG" "$GLASS"; do
  if qs -p "$root" ipc show >/dev/null 2>&1; then
    exec qs -p "$root" ipc call "$@"
  fi
done
exec qs ipc call "$@"
