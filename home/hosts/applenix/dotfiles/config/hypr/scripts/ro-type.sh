#!/usr/bin/env bash
# Romanian diacritics from Hyprland. Token: first arg (use: exec, bash …/ro-type.sh i).
# Needs: wl-copy, wtype, ydotoold for paste path; WAYLAND_DISPLAY is auto-detected if missing.
set -uo pipefail

# --- environment Hyprland "exec" often strips ---
export HOME="${HOME:-$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f6)}"
export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
uid="$(id -u)"
rt="${XDG_RUNTIME_DIR:-/run/user/$uid}"
if [ -z "${WAYLAND_DISPLAY:-}" ] && [ -d "$rt" ]; then
  # Prefer wayland-1 (typical Hyprland); glob order is unreliable.
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

STRAT="${RO_TYPE_STRATEGY:-paste_then_wtype}"
# Prefer argv (exec, bash …/ro-type.sh i). RO_TOKEN= is fallback.
tok="${1:-${RO_TOKEN:-}}"
case "$tok" in
  i) ch='î' ;;
  I) ch='Î' ;;
  a) ch='â' ;;
  A) ch='Â' ;;
  u) ch='ă' ;;
  U) ch='Ă' ;;
  s) ch='ș' ;;
  S) ch='Ș' ;;
  t) ch='ț' ;;
  T) ch='Ț' ;;
  *) exit 1 ;;
esac

warn() {
  command -v notify-send >/dev/null 2>&1 && notify-send -a ro-type "$1" "$2" &
}

paste_char() {
  local text=$1
  local prev_plain=""
  local can_restore=0

  if ! command -v wl-copy >/dev/null 2>&1; then
    return 1
  fi
  if [ -z "${WAYLAND_DISPLAY:-}" ]; then
    return 1
  fi

  if prev_plain=$(wl-paste -n --type text/plain 2>/dev/null); then
    can_restore=1
  else
    if wl-paste -l 2>/dev/null | grep -q .; then
      if ! wl-paste -l 2>/dev/null | grep -qF text/plain; then
        return 1
      fi
    fi
  fi

  if ! printf '%s' "$text" | wl-copy --type text/plain 2>/dev/null; then
    if ! printf '%s' "$text" | wl-copy 2>/dev/null; then
      return 1
    fi
  fi

  sleep 0.06
  local sent=0
  # Prefer ydotool for Ctrl+V (real evdev); wtype -M is a second virtual-keyboard path and can fail in exec.
  if command -v ydotool >/dev/null 2>&1; then
    if ydotool key 29:1 47:1 47:0 29:0 2>/dev/null; then
      sent=1
    fi
  fi
  if [ "$sent" = 0 ] && command -v wtype >/dev/null 2>&1; then
    if wtype -M ctrl v -m ctrl 2>/dev/null; then
      sent=1
    fi
  fi

  sleep 0.04
  if [ "$can_restore" = 1 ]; then
    printf '%s' "$prev_plain" | wl-copy --type text/plain 2>/dev/null || true
  fi

  [ "$sent" = 1 ]
}

try_wtype() {
  command -v wtype >/dev/null 2>&1 && wtype "$1" 2>/dev/null
}

main() {
  case "$STRAT" in
    wtype_then_paste)
      if try_wtype "$ch"; then exit 0; fi
      if paste_char "$ch"; then exit 0; fi
      ;;
    paste_then_wtype|*)
      if paste_char "$ch"; then exit 0; fi
      if try_wtype "$ch"; then exit 0; fi
      ;;
  esac

  warn "ro-type failed" "WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-?} ydotoold=$(systemctl --user is-active ydotoold 2>/dev/null || echo n/a)"
  exit 1
}

main
