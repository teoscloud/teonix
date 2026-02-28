#!/usr/bin/env bash
# Send NixOS system audio (PipeWire default sink monitor) to a receiver over UDP.
# Usage:
#   $0 <mac_ip> [port]              # plain UDP (LAN only)
#   $0 --ssh <user@mac> [port]      # encrypted via SSH (recommended)
# On Mac: run a receiver that listens on the same port and plays to BlackHole.
# Requires: parecord (pulseaudioFull), socat; for --ssh: SSH key login to Mac.

set -euo pipefail

PORT="49152"
USE_SSH=""
MAC_IP=""
SSH_TARGET=""

if [[ "${1:-}" == "--ssh" || "${1:-}" == "--encrypt" ]]; then
  USE_SSH=1
  SSH_TARGET="${2:-}"
  PORT="${3:-$PORT}"
  if [[ -z "$SSH_TARGET" ]]; then
    echo "Usage: $0 --ssh <user@mac> [port]" >&2
    echo "  Stream is encrypted over SSH. Requires SSH key from NixOS to Mac." >&2
    echo "  On Mac, start the receiver first (listen on 127.0.0.1:${PORT}, play to BlackHole)." >&2
    exit 1
  fi
else
  MAC_IP="${1:-}"
  PORT="${2:-$PORT}"
  if [[ -z "$MAC_IP" ]]; then
    echo "Usage: $0 <mac_ip> [port]" >&2
    echo "       $0 --ssh <user@mac> [port]   # encrypted" >&2
    echo "  Sends stereo 48kHz s16le PCM (default port $PORT)." >&2
    exit 1
  fi
fi

SINK="$(pactl get-default-sink 2>/dev/null)" || true
if [[ -z "$SINK" ]]; then
  echo "Could not get default Pulse sink. Is PipeWire/Pulse running?" >&2
  exit 1
fi

SOURCE="${SINK}.monitor"
if ! pactl list sources short | grep -q "^[0-9][0-9]*[[:space:]].*${SOURCE}"; then
  echo "Monitor source not found: $SOURCE" >&2
  echo "Available sources:" >&2
  pactl list sources short | sed 's/^/  /' >&2
  exit 1
fi

# Minimal sender-side buffering: stdbuf -o0 so pipe doesn't hold 10s of ms; -probesize/-analyzeduration = less FFmpeg input delay
if [[ -n "$USE_SSH" ]]; then
  echo "Sending system audio (${SOURCE}) to ${SSH_TARGET} (encrypted, port ${PORT}). Stop with Ctrl+C." >&2
  # No exec: keep this script as parent so toggle can pkill it
  # Remote Mac: use full path to socat (zsh -l often doesn't get Homebrew PATH)
  stdbuf -o0 ffmpeg -nostdin -y -probesize 32 -analyzeduration 0 -f pulse -i "$SOURCE" \
    -f s16le -acodec pcm_s16le -ar 48000 -ac 2 -fflags nobuffer -flags low_delay - 2>/dev/null | \
    ssh -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o Compression=no "$SSH_TARGET" "/opt/homebrew/bin/socat - UDP-SENDTO:127.0.0.1:${PORT} || /usr/local/bin/socat - UDP-SENDTO:127.0.0.1:${PORT}"
else
  echo "Sending system audio (${SOURCE}) to ${MAC_IP}:${PORT} (stereo 48kHz s16le). Stop with Ctrl+C." >&2
  echo -n "NixOS-audio" | socat - "UDP-SENDTO:${MAC_IP}:${PORT}" 2>/dev/null || true
  SCRIPT_DIR="$(dirname "$0")"
  exec stdbuf -o0 ffmpeg -nostdin -y -probesize 32 -analyzeduration 0 -f pulse -i "$SOURCE" \
    -f s16le -acodec pcm_s16le -ar 48000 -ac 2 -fflags nobuffer -flags low_delay - 2>/dev/null | \
    python3 "${SCRIPT_DIR}/udp-send-chunked.py" "${MAC_IP}" "${PORT}"
fi
