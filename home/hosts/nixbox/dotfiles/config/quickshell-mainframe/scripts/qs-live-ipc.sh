#!/usr/bin/env bash
# Call IPC on the Quickshell that is actually running (mainframe -p or glass default).
# `qs ipc` without -p always targets ~/.config/quickshell, so it misses a -p instance.
set -euo pipefail
MF="$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe"
GLASS="$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell"
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
  hyprctl keyword bind 'SUPER, N, exec, codium ~/myprojects/teonix-unstable/ && codium ~/.config/' >/dev/null
  exit 0
fi

if qs -p "$MF" ipc show >/dev/null 2>&1; then
  exec qs -p "$MF" ipc call "$@"
fi
if qs -p "$GLASS" ipc show >/dev/null 2>&1; then
  exec qs -p "$GLASS" ipc call "$@"
fi
exec qs ipc call "$@"
