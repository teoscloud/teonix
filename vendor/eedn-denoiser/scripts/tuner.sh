#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# Ensure live conf exists / is synced before opening UI
mkdir -p "$HOME/.config/pipewire/filter-chain.conf.d"
if [[ ! -f "$HOME/.config/pipewire/filter-chain.conf.d/eedn-pcm2902-mic.conf" ]]; then
  cp -f "$ROOT/pipewire/eedn-pcm2902-mic.conf" "$HOME/.config/pipewire/filter-chain.conf.d/"
fi
exec python3 "$ROOT/gui/eedn_tuner.py"
