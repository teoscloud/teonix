#!/usr/bin/env bash
# Applenix: pactl fallback when buschain-control is not installed.
set -euo pipefail

try_bins=(
  "buschain-ctl"
  "${HOME}/Projects/buschain-control/target/debug/buschain-ctl"
  "${HOME}/Projects/buschain-control/target/release/buschain-ctl"
  "${HOME}/.local/bin/buschain-ctl"
)

for b in "${try_bins[@]}"; do
  if [[ "$b" == /* ]]; then
    if [[ -x "$b" ]]; then
      exec "$b" "$@"
    fi
  elif command -v "$b" >/dev/null 2>&1; then
    exec "$b" "$@"
  fi
done

cmd="${1:-status}"
shift || true

pactl_default_status() {
  local mute vol muted class sink
  sink="@DEFAULT_SINK@"
  mute=$(pactl get-sink-mute "$sink" 2>/dev/null | awk '{print $2}' || echo no)
  vol=$(pactl get-sink-volume "$sink" 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%' || echo 0)
  vol=${vol:-0}
  (( vol > 100 )) && vol=100
  muted=false
  class="normal"
  if [[ "$mute" == "yes" ]]; then
    muted=true
    class="muted"
  fi
  printf '{"percentage":%s,"muted":%s,"class":"%s","tooltip":"Default sink (pactl)"}\n' "$vol" "$muted" "$class"
}

case "$cmd" in
  status)
    pactl_default_status
    ;;
  hw-vol)
    dir="${1:-up}"
    case "$dir" in
      up) pactl set-sink-volume @DEFAULT_SINK@ +5% ;;
      down) pactl set-sink-volume @DEFAULT_SINK@ -5% ;;
      *) exit 2 ;;
    esac
    ;;
  mixer)
    printf '{"tracks":[],"status":{"master_hw":"@DEFAULT_SINK@"}}\n'
    ;;
  *)
    pactl_default_status
    ;;
esac
