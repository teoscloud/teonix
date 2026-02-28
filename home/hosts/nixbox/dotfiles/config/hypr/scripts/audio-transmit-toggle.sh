#!/usr/bin/env bash
# Toggle NixOS → Mac audio transmit (SSH). Start if not running, stop if running.
# Only kills the transmit process and its children (never process group).

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PID_FILE="$SCRIPT_DIR/.audio-transmit-ssh.pid"

if [[ -f "$PID_FILE" ]]; then
  PID=$(cat "$PID_FILE")
  rm -f "$PID_FILE"
  if kill -0 "$PID" 2>/dev/null; then
    # Kill entire subtree (children, grandchildren, ...) then parent; SIGKILL for instant stop (UDP)
    kill_tree() {
      for p in $(pgrep -P "$1" 2>/dev/null); do
        kill_tree "$p"
        kill -9 "$p" 2>/dev/null
      done
    }
    kill_tree "$PID"
    kill -9 "$PID" 2>/dev/null
  fi
  notify-send "Audio transmit" "Stopped sending audio to Mac" 2>/dev/null || true
else
  "$SCRIPT_DIR/audio-transmit.sh" --ssh teodorstan@192.168.0.93 49152 &
  echo $! > "$PID_FILE"
  notify-send "Audio transmit" "Started sending audio to Mac" 2>/dev/null || true
fi
