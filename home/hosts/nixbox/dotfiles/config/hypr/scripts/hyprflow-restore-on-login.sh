#!/usr/bin/env bash
# Restore the richest recent autosave (or latest), after Hyprland + monitors settle.
# Prefer autosave-* within MAX_AGE; fall back to latest.json.
set -euo pipefail

MAX_AGE_HOURS=36
RESTORE_DELAY_SEC=3

export PATH="/run/current-system/sw/bin:${HOME}/.nix-profile/bin:${PATH:-}"
SESSIONS_DIR="${XDG_DATA_HOME:-$HOME}/.local/share/hyprflow/sessions"

# Wait for Hyprland IPC + at least one monitor
for _ in $(seq 1 30); do
  if hyprctl monitors -j >/dev/null 2>&1; then
    break
  fi
  sleep 0.5
done
sleep "$RESTORE_DELAY_SEC"

pick_best_autosave() {
  python3 - "$SESSIONS_DIR" "$MAX_AGE_HOURS" <<'PY'
import glob
import json
import os
import sys
import time

sessions_dir = sys.argv[1]
max_age = int(sys.argv[2]) * 3600
now = time.time()
best_name = None
best_count = -1
best_mtime = 0.0

for path in glob.glob(os.path.join(sessions_dir, "autosave-*.json")):
    try:
        mtime = os.path.getmtime(path)
    except OSError:
        continue
    if now - mtime > max_age:
        continue
    try:
        with open(path) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        continue
    count = len(data.get("clients", []))
    if count > best_count or (count == best_count and mtime > best_mtime):
        best_name = os.path.splitext(os.path.basename(path))[0]
        best_count = count
        best_mtime = mtime

if best_name:
    print(best_name)
PY
}

if [[ ! -d "$SESSIONS_DIR" ]]; then
  echo "hyprflow-restore: no sessions directory, skipping" >&2
  exit 0
fi

if ! command -v hyprflow >/dev/null 2>&1; then
  echo "hyprflow-restore: hyprflow not in PATH, skipping" >&2
  exit 0
fi

session="$(pick_best_autosave || true)"
if [[ -n "$session" ]]; then
  echo "hyprflow-restore: restoring '$session'" >&2
  exec hyprflow restore "$session" --verbose
fi

if [[ -f "$SESSIONS_DIR/latest.json" ]]; then
  echo "hyprflow-restore: no recent autosave, trying latest" >&2
  exec hyprflow restore latest --max-age "${MAX_AGE_HOURS}h" --verbose
fi

echo "hyprflow-restore: nothing to restore" >&2
exit 0
