#!/usr/bin/env bash
# Switch to White Mainframe Quickshell + Hyprland decoration.
# Always replace any running Quickshell — never stack instances.
set -euo pipefail
MF="$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe"
DEC="$HOME/teonix/home/hosts/nixbox/dotfiles/config/hypr/mainframe-decoration.conf"
KILL="$MF/scripts/qs-kill-all.sh"

if [[ -f "$DEC" ]] && command -v hyprctl >/dev/null; then
  # Lua config: live decoration through `hyprctl eval` (no `hyprctl keyword`).
  hyprctl eval '
    hl.config({
      decoration = { rounding = 9, rounding_power = 1, shadow = { enabled = false }, blur = { enabled = false } },
      general = { border_size = 1, col = {
        active_border = { colors = { "rgba(2a2e34ee)", "rgba(fffffff0)" }, angle = 45 },
        inactive_border = "rgba(9aa0a8aa)" } },
    })
    hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
    hl.animation({ leaf = "borderangle", enabled = true, speed = 22, bezier = "linear", style = "loop" })
    hl.animation({ leaf = "windowsIn", enabled = true, speed = 4, bezier = "default", style = "popin 55%" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 3, bezier = "default", style = "popin 55%" })
  ' >/dev/null 2>&1 || true
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
