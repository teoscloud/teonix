#!/usr/bin/env bash
# Restore glass Quickshell + rounded Hyprland decoration.
# Always replace any running Quickshell — never stack instances.
set -euo pipefail
ROOT="$HOME/teonix/home/hosts/nixbox/dotfiles/config"
GLASS="$ROOT/quickshell"
KILL="$ROOT/quickshell-mainframe/scripts/qs-kill-all.sh"

if command -v hyprctl >/dev/null; then
  # Lua config: live decoration through `hyprctl eval` (no `hyprctl keyword`).
  hyprctl eval '
    hl.config({
      decoration = { rounding = 10, rounding_power = 2, shadow = { enabled = true }, blur = { enabled = true } },
      general = { border_size = 1, col = {
        active_border = { colors = { "rgba(141417ee)", "rgba(FFFFFFee)" }, angle = 45 },
        inactive_border = "rgba(595959aa)" } },
    })
    hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })
    hl.animation({ leaf = "borderangle", enabled = true, speed = 30, bezier = "linear", style = "loop" })
    hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "default" })
    hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
  ' >/dev/null 2>&1 || true
fi

bash "$KILL"
bash "$ROOT/quickshell-mainframe/scripts/qs-live-ipc.sh" --install-binds || true

exec qs -p "$GLASS" -d
