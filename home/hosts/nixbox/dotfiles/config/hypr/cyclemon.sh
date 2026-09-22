#!/usr/bin/env bash
# Cycle focus through every connected output and teleport the cursor onto
# that monitor's current workspace. Wraps. No connector names — order is
# left-to-right, then top-to-bottom, so the walk stays the same after a
# recable.
set -uo pipefail

have_hypr() { hyprctl monitors -j >/dev/null 2>&1; }
have_hypr || { printf 'cyclemon: hyprland not reachable\n' >&2; exit 1; }

# `hyprctl … -j` cannot be piped into a heredoc python; snapshot first.
f="$(mktemp "${TMPDIR:-/tmp}/teonix-cyclemon.XXXXXX")" || exit 1
if ! hyprctl monitors -j >"$f" 2>/dev/null || [ ! -s "$f" ]; then
  rm -f "$f"
  exit 1
fi

read -r name ws cx cy < <(python3 - "$f" <<'PY'
import json, sys
mons = json.load(open(sys.argv[1]))
if not mons:
    sys.exit(1)
mons.sort(key=lambda m: (m.get("x", 0), m.get("y", 0), m.get("description", ""), m["name"]))
idx = next((i for i, m in enumerate(mons) if m.get("focused")), 0)
nxt = mons[(idx + 1) % len(mons)]
ws = (nxt.get("activeWorkspace") or {}).get("id", "")
cx = int(nxt["x"] + nxt["width"] / 2)
cy = int(nxt["y"] + nxt["height"] / 2)
print(nxt["name"], ws, cx, cy)
PY
)
rm -f "$f"

[ -n "${name:-}" ] || exit 1

# Lua config: dispatchers go through `hyprctl eval`.
hyprctl eval "hl.dispatch(hl.dsp.focus({ monitor = \"$name\" }))" >/dev/null 2>&1
if [ -n "$ws" ]; then
  hyprctl eval "hl.dispatch(hl.dsp.focus({ workspace = \"$ws\" }))" >/dev/null 2>&1
fi
hyprctl eval "hl.dispatch(hl.dsp.cursor.move({ x = $cx, y = $cy }))" >/dev/null 2>&1
