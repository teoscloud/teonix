#!/usr/bin/env bash
# Make EEDN (denoised PCM2902 → Easy Effects) start on login,
# and keep the old raw NixOS pcm2902-listen loopback off.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"

if [[ ! -f "$PREFIX/lib/ladspa/eedn_denoiser.so" ]]; then
  echo "Plugin not installed. Building/installing first..."
  if command -v nix-shell >/dev/null; then
    nix-shell --run "make -C '$ROOT' install"
  else
    make -C "$ROOT" install
  fi
fi

mkdir -p "$HOME/.config/pipewire/filter-chain.conf.d"
mkdir -p "$HOME/.config/systemd/user"
cp -f "$ROOT/pipewire/eedn-pcm2902-mic.conf" "$HOME/.config/pipewire/filter-chain.conf.d/"
cp -f "$ROOT/systemd/eedn-pcm2902.service" "$HOME/.config/systemd/user/"

systemctl --user daemon-reload

# Stop + mask the old raw loopback (NixOS unit)
if systemctl --user cat pcm2902-listen.service >/dev/null 2>&1; then
  systemctl --user stop pcm2902-listen.service 2>/dev/null || true
  systemctl --user mask pcm2902-listen.service
  echo "Masked pcm2902-listen.service (raw undenoised loopback)."
fi

systemctl --user enable --now eedn-pcm2902.service

echo
echo "Autostart OK."
echo "  On login: PCM2902 mic → EEDN → Easy Effects Sink"
echo
echo "Check:  systemctl --user status eedn-pcm2902.service"
echo "Disable later:"
echo "  systemctl --user disable --now eedn-pcm2902.service"
echo "  systemctl --user unmask pcm2902-listen.service && systemctl --user start pcm2902-listen.service"
echo
echo "Optional (NixOS): remove/disable the pcm2902-listen module from your system"
echo "config so a future rebuild does not fight the mask."
