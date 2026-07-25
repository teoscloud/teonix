#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PREFIX="${PREFIX:-$HOME/.local}"
export PREFIX

echo "==> Building EEDN denoiser (PREFIX=$PREFIX)"
make clean
make -j"$(nproc)"
make install

PW_DIR="$HOME/.config/pipewire/filter-chain.conf.d"
mkdir -p "$PW_DIR"
cp -f "$ROOT/pipewire/eedn-denoise-sink.conf" "$PW_DIR/eedn-denoise-sink.conf"

# Ensure LADSPA/LV2 paths for user session
PROFILE_SNIPPET="$HOME/.config/eedn/env.sh"
mkdir -p "$(dirname "$PROFILE_SNIPPET")"
cat > "$PROFILE_SNIPPET" <<EOF
export LV2_PATH="$PREFIX/lib/lv2:\${LV2_PATH:-/usr/lib/lv2:/usr/local/lib/lv2}"
export LADSPA_PATH="$PREFIX/lib/ladspa:\${LADSPA_PATH:-/usr/lib/ladspa:/usr/local/lib/ladspa}"
EOF

echo
echo "Installed."
echo "  LV2:    $PREFIX/lib/lv2/eedn.lv2"
echo "  LADSPA: $PREFIX/lib/ladspa/eedn_denoiser.so"
echo "  PipeWire filter-chain config: $PW_DIR/eedn-denoise-sink.conf"
echo
echo "Use with PCM2902 (recommended — stops Easy Effects stealing that output):"
echo "  source $PROFILE_SNIPPET"
echo "  ./scripts/use-pcm2902.sh"
echo
echo "That sets: apps → EEDN Denoiser Sink → PCM2902 (hard-pinned)."
echo "Keep Easy Effects Output Device on Scarlett/elsewhere, not PCM2902."
