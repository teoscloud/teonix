#!/usr/bin/env bash
# Toggle NixOS → Mac audio transmit. Mutually exclusive SSH vs UDP.
# Usage: audio-transmit-toggle.sh ssh | udp
#   ssh — Meta+Shift+L (encrypted, higher latency)
#   udp — Meta+Shift+; (LAN UDP, lower latency; Mac listens on this host:port, not localhost-only)

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SSH_PID_FILE="$SCRIPT_DIR/.audio-transmit-ssh.pid"
UDP_PID_FILE="$SCRIPT_DIR/.audio-transmit-udp.pid"

SSH_TARGET="teodorstan@192.168.0.93"
PORT="49152"
# Same machine as SSH target; Mac receiver must bind UDP on LAN iface (0.0.0.0), not only 127.0.0.1
UDP_HOST="${SSH_TARGET##*@}"

kill_tree() {
  local root="$1"
  local p
  for p in $(pgrep -P "$root" 2>/dev/null); do
    kill_tree "$p"
    kill -9 "$p" 2>/dev/null || true
  done
}

stop_from_pidfile() {
  local f="$1"
  [[ -f "$f" ]] || return 0
  local pid
  pid=$(tr -d '[:space:]' <"$f" 2>/dev/null || true)
  rm -f "$f"
  [[ -n "${pid:-}" ]] || return 0
  if kill -0 "$pid" 2>/dev/null; then
    kill_tree "$pid"
    kill -9 "$pid" 2>/dev/null || true
  fi
}

stop_ssh() { stop_from_pidfile "$SSH_PID_FILE"; }
stop_udp() { stop_from_pidfile "$UDP_PID_FILE"; }

toggle_ssh() {
  if [[ -f "$SSH_PID_FILE" ]] && kill -0 "$(tr -d '[:space:]' <"$SSH_PID_FILE")" 2>/dev/null; then
    stop_ssh
    notify-send "Audio transmit" "Stopped (SSH)" 2>/dev/null || true
    return
  fi
  rm -f "$SSH_PID_FILE"
  stop_udp
  "$SCRIPT_DIR/audio-transmit.sh" --ssh "$SSH_TARGET" "$PORT" &
  echo $! >"$SSH_PID_FILE"
  notify-send "Audio transmit" "Started SSH → ${SSH_TARGET} (port ${PORT})" 2>/dev/null || true
}

toggle_udp() {
  if [[ -f "$UDP_PID_FILE" ]] && kill -0 "$(tr -d '[:space:]' <"$UDP_PID_FILE")" 2>/dev/null; then
    stop_udp
    notify-send "Audio transmit" "Stopped (UDP)" 2>/dev/null || true
    return
  fi
  rm -f "$UDP_PID_FILE"
  stop_ssh
  "$SCRIPT_DIR/audio-transmit.sh" "$UDP_HOST" "$PORT" &
  echo $! >"$UDP_PID_FILE"
  notify-send "Audio transmit" "Started UDP → ${UDP_HOST}:${PORT} (LAN)" 2>/dev/null || true
}

MODE="${1:-ssh}"
case "$MODE" in
  ssh) toggle_ssh ;;
  udp) toggle_udp ;;
  *)
    echo "Usage: $0 ssh|udp" >&2
    exit 1
    ;;
esac
