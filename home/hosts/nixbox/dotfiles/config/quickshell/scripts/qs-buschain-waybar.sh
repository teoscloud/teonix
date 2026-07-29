#!/usr/bin/env bash
# Resolve buschain-waybar for Quickshell; fall back to pactl when offline.
set -euo pipefail

pactl_status() {
  local sink mute vol muted class
  sink="@DEFAULT_SINK@"
  mute=$(pactl get-sink-mute "$sink" 2>/dev/null | awk '{print $2}' || true)
  vol=$(pactl get-sink-volume "$sink" 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%' || true)
  vol=${vol:-0}
  (( vol > 100 )) && vol=100
  muted=false
  class="normal"
  if [[ "$mute" == "yes" ]]; then
    muted=true
    class="muted"
  fi
  printf '{"percentage":%s,"muted":%s,"class":"%s","tooltip":"Master HW (pactl)"}\n' "$vol" "$muted" "$class"
}

pactl_up() {
  local sink cur
  sink="@DEFAULT_SINK@"
  pactl set-sink-volume "$sink" +5% 2>/dev/null || true
  cur=$(pactl get-sink-volume "$sink" 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%' || true)
  if [[ -n "${cur:-}" && "$cur" -gt 100 ]]; then
    pactl set-sink-volume "$sink" 100% 2>/dev/null || true
  fi
}

pactl_down() {
  pactl set-sink-volume "@DEFAULT_SINK@" -5% 2>/dev/null || true
}

find_buschain_waybar() {
  local b
  for b in \
    "buschain-waybar" \
    "${HOME}/.local/bin/buschain-waybar" \
    "${HOME}/.config/waybar/buschain-waybar.sh" \
    "${HOME}/Projects/buschain-control/packaging/waybar/buschain-waybar.sh"
  do
    if [[ "$b" == /* ]]; then
      [[ -x "$b" ]] && { printf '%s\n' "$b"; return 0; }
    elif command -v "$b" >/dev/null 2>&1; then
      command -v "$b"
      return 0
    fi
  done
  return 1
}

buschain_online() {
  local bin out
  bin=$(find_buschain_waybar) || return 1
  out=$("$bin" status 2>/dev/null || true)
  [[ -n "$out" && "$out" != *'"class":"offline"'* && "$out" == *'"percentage"'* ]]
}

cmd="${1:-status}"
bin=$(find_buschain_waybar || true)

case "$cmd" in
  status)
    if [[ -n "${bin:-}" ]] && out=$("$bin" status 2>/dev/null); then
      if [[ "$out" == *'"class":"offline"'* ]] || [[ "$out" != *'"percentage"'* ]]; then
        pactl_status
      else
        # Normalize for QS VolumePill (percentage field)
        printf '%s\n' "$out"
      fi
    else
      pactl_status
    fi
    ;;
  up)
    if buschain_online; then
      "$(find_buschain_waybar)" up >/dev/null 2>&1 || pactl_up
    else
      pactl_up
    fi
    ;;
  down)
    if buschain_online; then
      "$(find_buschain_waybar)" down >/dev/null 2>&1 || pactl_down
    else
      pactl_down
    fi
    ;;
  *)
    echo "usage: qs-buschain-waybar.sh status|up|down" >&2
    exit 2
    ;;
esac
