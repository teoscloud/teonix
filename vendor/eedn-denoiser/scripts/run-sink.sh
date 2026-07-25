#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
export LV2_PATH="$PREFIX/lib/lv2:${LV2_PATH:-}"
export LADSPA_PATH="$PREFIX/lib/ladspa:${LADSPA_PATH:-}"

CONF="$HOME/.config/pipewire/filter-chain.conf.d/eedn-denoise-sink.conf"
if [[ ! -f "$CONF" ]]; then
  CONF="$ROOT/pipewire/eedn-denoise-sink.conf"
fi

if [[ ! -f "$PREFIX/lib/ladspa/eedn_denoiser.so" ]]; then
  echo "Plugin not installed. Run: nix-shell --run ./scripts/install.sh" >&2
  exit 1
fi

exec pipewire -c "$CONF"
