#!/usr/bin/env bash
# Replace NixOS pcm2902-listen (raw loopback) with: PCM2902 mic → EEDN → Easy Effects.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
export LV2_PATH="$PREFIX/lib/lv2:${LV2_PATH:-}"
export LADSPA_PATH="$PREFIX/lib/ladspa:${LADSPA_PATH:-}"

PCM_IN="alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo-input"
CONF_SRC="$ROOT/pipewire/eedn-pcm2902-mic.conf"
CONF="$HOME/.config/pipewire/filter-chain.conf.d/eedn-pcm2902-mic.conf"
UNIT_SRC="$ROOT/systemd/eedn-pcm2902.service"
UNIT_DST="$HOME/.config/systemd/user/eedn-pcm2902.service"

if [[ ! -f "$PREFIX/lib/ladspa/eedn_denoiser.so" ]]; then
  echo "Plugin missing. Run: nix-shell --run ./scripts/install.sh" >&2
  exit 1
fi

mkdir -p "$(dirname "$CONF")" "$(dirname "$UNIT_DST")"
cp -f "$CONF_SRC" "$CONF"
cp -f "$UNIT_SRC" "$UNIT_DST"

find_node_id_by_name() {
  pw-dump 2>/dev/null | python3 -c '
import json, sys
want = sys.argv[1]
for o in json.load(sys.stdin):
    props = (o.get("info") or {}).get("props") or {}
    if props.get("node.name") == want:
        print(o["id"]); break
' "$1"
}

PCM_ID="$(find_node_id_by_name "$PCM_IN" || true)"
if [[ -z "${PCM_ID:-}" ]]; then
  PCM_ID="$(pw-dump 2>/dev/null | python3 -c '
import json
for o in json.load(sys.stdin):
    p=(o.get("info") or {}).get("props") or {}
    if p.get("media.class")=="Audio/Source" and "PCM2902" in (p.get("node.description") or ""):
        print(o["id"]); break
')"
fi
if [[ -z "${PCM_ID:-}" ]]; then
  echo "PCM2902 mic source not found. Is the USB device plugged in?" >&2
  exit 1
fi
PCM_NAME="$(wpctl inspect "$PCM_ID" 2>/dev/null | awk -F'"' '/node.name =/{print $2; exit}')"
[[ -n "${PCM_NAME:-}" ]] && PCM_IN="$PCM_NAME"
echo "Capture from: id=$PCM_ID name=$PCM_IN"
sed -i "s|target.object    = \"alsa_input\.[^\"]*\"|target.object    = \"${PCM_IN}\"|" "$CONF"

# Stop the NixOS raw loopback that appears as "PCM2902 output" → Easy Effects
if systemctl --user is-active --quiet pcm2902-listen.service 2>/dev/null; then
  echo "Stopping pcm2902-listen.service (raw loopback)..."
  systemctl --user stop pcm2902-listen.service
fi

# Stop any ad-hoc EEDN processes from earlier scripts
pkill -f "pipewire -c .*eedn-(denoise-sink|pcm2902-mic)\\.conf" 2>/dev/null || true
systemctl --user stop eedn-pcm2902.service 2>/dev/null || true
sleep 0.3

systemctl --user daemon-reload
systemctl --user start eedn-pcm2902.service

sleep 0.8
if systemctl --user is-active --quiet eedn-pcm2902.service; then
  echo "eedn-pcm2902.service is active."
else
  echo "Service failed to start:" >&2
  systemctl --user status eedn-pcm2902.service --no-pager >&2 || true
  exit 1
fi

PLAY_ID="$(find_node_id_by_name "eedn_pcm2902_playback" || true)"
echo
echo "Chain:  PCM2902 mic  →  EEDN  →  Easy Effects Sink"
[[ -n "${PLAY_ID:-}" ]] && echo "Playback node id: $PLAY_ID"
echo
echo "pavucontrol Playback should show:"
echo "  EEDN PCM2902 (denoised)  →  Easy Effects Sink"
echo
echo "Enable on login:"
echo "  systemctl --user enable eedn-pcm2902.service"
echo "  systemctl --user mask pcm2902-listen.service   # stop NixOS loopback from coming back"
echo
echo "Stop:"
echo "  systemctl --user stop eedn-pcm2902.service"
