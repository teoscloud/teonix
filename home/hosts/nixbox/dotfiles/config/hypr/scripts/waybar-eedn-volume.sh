#!/usr/bin/env bash
# Waybar status/mute helper for EEDN PCM2902 (denoised) playback volume.
# Scroll up/down is handled by inline pactl in waybar config (faster — Waybar
# drops on-scroll events while a previous command is still running).
set -euo pipefail

MAX_PCT=300
STEP=5
ICON="󰊴"
ID_FILE="${XDG_RUNTIME_DIR:-/tmp}/waybar-eedn-volume.id"

find_input() {
  pactl --format=json list sink-inputs 2>/dev/null | python3 -c '
import json, sys
for s in json.load(sys.stdin):
    p = s.get("properties") or {}
    if p.get("node.name") != "eedn_pcm2902_playback" and p.get("media.name") != "EEDN PCM2902 (denoised)":
        continue
    vol = s.get("volume") or {}
    pcts = []
    for ch in vol.values():
        if isinstance(ch, dict) and "value_percent" in ch:
            pcts.append(float(str(ch["value_percent"]).rstrip("%")))
        elif isinstance(ch, dict) and "value" in ch:
            pcts.append(100.0 * float(ch["value"]) / 65536.0)
    pct = int(round(sum(pcts) / len(pcts))) if pcts else 0
    print("%s %s %s" % (s["index"], pct, int(bool(s.get("mute")))))
    sys.exit(0)
sys.exit(1)
'
}

emit() {
  local pct="$1" mute="$2" offline="${3:-0}"
  if [[ "$offline" == "1" ]]; then
    printf '{"text":"%s —","tooltip":"EEDN denoise stream not running","class":"offline"}\n' "$ICON"
    return
  fi
  local cls="ok"
  [[ "$mute" == "1" ]] && cls="muted"
  (( pct > 100 )) && cls="hot"
  printf '{"text":"%s %s%%","tooltip":"EEDN PCM2902 (denoised)\\nScroll: ±%s%% (max %s%%)\\nClick: mute","class":"%s"}\n' \
    "$ICON" "$pct" "$STEP" "$MAX_PCT" "$cls"
}

cmd="${1:-status}"

case "$cmd" in
  status)
    if ! info="$(find_input)"; then
      rm -f "$ID_FILE"
      emit 0 0 1
      exit 0
    fi
    read -r id pct mute <<<"$info"
    echo "$id" >"$ID_FILE"
    # Keep stream within scroll limits if inline ±5% overshot.
    if (( pct > MAX_PCT )); then
      pactl set-sink-input-volume "$id" "${MAX_PCT}%"
      pct=$MAX_PCT
    elif (( pct < 0 )); then
      pactl set-sink-input-volume "$id" 0%
      pct=0
    fi
    emit "$pct" "$mute"
    ;;
  mute)
    if info="$(find_input)"; then
      read -r id pct mute <<<"$info"
      echo "$id" >"$ID_FILE"
      pactl set-sink-input-mute "$id" toggle
      pkill -RTMIN+8 waybar >/dev/null 2>&1 || true
    fi
    ;;
  # Kept for manual use / debugging
  up|down)
    if ! info="$(find_input)"; then
      exit 0
    fi
    read -r id pct mute <<<"$info"
    echo "$id" >"$ID_FILE"
    if [[ "$cmd" == "up" ]]; then
      pactl set-sink-input-mute "$id" 0
      pactl set-sink-input-volume "$id" +${STEP}%
    else
      pactl set-sink-input-volume "$id" -${STEP}%
    fi
    ;;
  *)
    echo "usage: $0 {status|mute|up|down}" >&2
    exit 2
    ;;
esac
