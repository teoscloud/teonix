#!/usr/bin/env bash
# Applenix: PipeWire default sink for Quickshell volume pill (no buschain-control).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CTL_WRAP="${SCRIPT_DIR}/qs-buschain-ctl.sh"

pactl_status() {
  local mute vol muted class
  mute=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}' || echo no)
  vol=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%' || echo 0)
  vol=${vol:-0}
  (( vol > 100 )) && vol=100
  muted=false
  class="normal"
  if [[ "$mute" == "yes" ]]; then
    muted=true
    class="muted"
  fi
  printf '{"percentage":%s,"muted":%s,"class":"%s","tooltip":"Default sink"}\n' "$vol" "$muted" "$class"
}

cmd="${1:-status}"

case "$cmd" in
  status)
    if [[ -x "$CTL_WRAP" ]]; then
      if out=$("$CTL_WRAP" status 2>/dev/null); then
        if [[ "$out" == *'"percentage"'* ]]; then
          printf '%s\n' "$out"
          exit 0
        fi
      fi
    fi
    pactl_status
    ;;
  up)
    pactl set-sink-volume @DEFAULT_SINK@ +5% 2>/dev/null || true
    ;;
  down)
    pactl set-sink-volume @DEFAULT_SINK@ -5% 2>/dev/null || true
    ;;
  *)
    echo "usage: qs-buschain-waybar.sh status|up|down" >&2
    exit 2
    ;;
esac
