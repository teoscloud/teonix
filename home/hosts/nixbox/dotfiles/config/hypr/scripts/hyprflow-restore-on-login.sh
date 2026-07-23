#!/usr/bin/env bash
# Pick the best recent autosave (most windows) instead of stale `latest`.
# `hyprflow restore --max-age 24h` alone skips when latest.json is old but autosaves exist.
set -euo pipefail

MAX_AGE_HOURS=24
RESTORE_DELAY_SEC=2

SESSIONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/hyprflow/sessions"

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

session="$(pick_best_autosave || true)"
if [[ -n "$session" ]]; then
  echo "hyprflow-restore: restoring '$session'" >&2
  exec hyprflow restore "$session"
fi

if [[ -f "$SESSIONS_DIR/latest.json" ]]; then
  echo "hyprflow-restore: no recent autosave, trying latest" >&2
  exec hyprflow restore latest --max-age "${MAX_AGE_HOURS}h"
fi

echo "hyprflow-restore: nothing to restore" >&2
exit 0
