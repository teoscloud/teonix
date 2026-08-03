#!/usr/bin/env bash
# Insert text into a Hyprland client after a Quickshell overlay closes.
# Usage: qs-insert-text.sh [--focus 0xADDR] [--delay MS] [--] TEXT
#
# Mirrors wofi-emoji: focus the target window, then wtype the unicode.
# Falls back to clipboard + hyprctl sendshortcut CTRL,V.
set -uo pipefail

export HOME="${HOME:-$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)}"
export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
uid="$(id -u)"
rt="${XDG_RUNTIME_DIR:-/run/user/$uid}"
export XDG_RUNTIME_DIR="$rt"

if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -d "$rt" ]; then
  if [ -S "$rt/wayland-1" ]; then
    export WAYLAND_DISPLAY=wayland-1
  elif [ -S "$rt/wayland-0" ]; then
    export WAYLAND_DISPLAY=wayland-0
  else
    for s in "$rt"/wayland-*; do
      if [ -S "$s" ]; then
        export WAYLAND_DISPLAY="${s##*/}"
        break
      fi
    done
  fi
fi

# ydotoold on NixOS/systemd uses $XDG_RUNTIME_DIR/.ydotool_socket, not /tmp
if [ -z "${YDOTOOL_SOCKET:-}" ]; then
  if [ -S "$rt/.ydotool_socket" ]; then
    export YDOTOOL_SOCKET="$rt/.ydotool_socket"
  elif [ -S /tmp/.ydotool_socket ]; then
    export YDOTOOL_SOCKET=/tmp/.ydotool_socket
  fi
fi

delay_ms=100
focus_addr=""
while [ $# -gt 0 ]; do
  case "$1" in
    --delay)
      delay_ms="${2:-100}"
      shift 2
      ;;
    --focus)
      focus_addr="${2:-}"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    -*)
      shift
      ;;
    *)
      break
      ;;
  esac
done

text="${*:-}"
if [ -z "$text" ] && [ ! -t 0 ]; then
  text="$(cat)"
fi
if [ -z "$text" ]; then
  exit 1
fi

sleep "$(awk "BEGIN { printf \"%.3f\", ${delay_ms}/1000 }")"

# Return focus to the window that was active before the overlay opened
if [ -n "$focus_addr" ]; then
  case "$focus_addr" in
    0x*|0X*) ;;
    *) focus_addr="0x$focus_addr" ;;
  esac
  hyprctl dispatch focuswindow "address:$focus_addr" >/dev/null 2>&1 || true
  sleep 0.08
else
  hyprctl dispatch focuscurrentorlast >/dev/null 2>&1 || true
  sleep 0.08
fi

# Keep a copy on the clipboard (handy if type/paste fails in some apps)
printf '%s' "$text" | wl-copy --type text/plain 2>/dev/null \
  || printf '%s' "$text" | wl-copy 2>/dev/null \
  || true

# Primary path — same as wofi-emoji
if command -v wtype >/dev/null 2>&1; then
  if wtype -- "$text" 2>/dev/null || wtype "$text" 2>/dev/null; then
    exit 0
  fi
fi

# Hyprland-native paste into the (now focused) client
if hyprctl dispatch sendshortcut "CTRL,V," >/dev/null 2>&1; then
  exit 0
fi

# Last resort: real key events via ydotool
if command -v ydotool >/dev/null 2>&1; then
  if ydotool key 29:1 47:1 47:0 29:0 2>/dev/null; then
    exit 0
  fi
fi

if command -v wtype >/dev/null 2>&1 && wtype -M ctrl v -m ctrl 2>/dev/null; then
  exit 0
fi

exit 1
