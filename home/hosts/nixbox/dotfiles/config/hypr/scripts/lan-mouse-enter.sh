#!/usr/bin/env bash
# Super+Ctrl on Linux → Windows. Must wait until Super and Ctrl are UP before
# crossing the barrier. If we enter while they are still down, Windows sees the
# same chord as lan-mouse release_bind and immediately sends us back.
set -euo pipefail

export PATH="/run/current-system/sw/bin:${HOME:-}/.nix-profile/bin:${PATH:-}"
uid="$(id -u)"
rt="${XDG_RUNTIME_DIR:-/run/user/$uid}"
export YDOTOOL_SOCKET="${YDOTOOL_SOCKET:-$rt/.ydotool_socket}"
log="$rt/lan-mouse-enter.log"
stamp="$rt/lan-mouse-enter.stamp"

exec 9>"$rt/lan-mouse-enter.lock"
flock 9

log() { printf '%s %s\n' "$(date +%H:%M:%S)" "$*" >>"$log"; }

now="$(date +%s%3N)"
if [ -f "$stamp" ]; then
  last="$(cat "$stamp" 2>/dev/null || echo 0)"
  if [ $((now - last)) -lt 800 ]; then
    log "debounce ${now}-${last}"
    exit 0
  fi
fi

if ! hyprctl monitors -j >/dev/null 2>&1; then
  log "hyprctl not available"
  exit 1
fi

log "wait for Super/Ctrl up"
python3 - <<'PY'
import array, fcntl, glob, os, time

KEY_LEFTCTRL, KEY_RIGHTCTRL = 29, 97
KEY_LEFTMETA, KEY_RIGHTMETA = 125, 126
CODES = (KEY_LEFTCTRL, KEY_RIGHTCTRL, KEY_LEFTMETA, KEY_RIGHTMETA)

def eviocgkey(n):
    return (2 << 30) | (n << 16) | (ord("E") << 8) | 0x18

def held():
    ioctl = eviocgkey(128)
    for path in glob.glob("/dev/input/event*"):
        try:
            fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
        except OSError:
            continue
        try:
            buf = array.array("B", [0] * 128)
            fcntl.ioctl(fd, ioctl, buf)
            if any(buf[c // 8] & (1 << (c % 8)) for c in CODES):
                return True
        except OSError:
            pass
        finally:
            os.close(fd)
    return False

deadline = time.time() + 2.0
while held() and time.time() < deadline:
    time.sleep(0.02)
PY

read -r x y < <(hyprctl monitors -j | python3 -c '
import json, sys
mons = json.load(sys.stdin)
if not mons:
    sys.exit(1)
left = min(mons, key=lambda m: m["x"])
print(int(left["x"] + 80), int(left["y"] + left["height"] // 2))
')

log "warp $x $y then ydotool left"
hyprctl dispatch movecursor "$x" "$y"
sleep 0.04
if ydotool mousemove -- -240 0; then
  log "ydotool ok"
else
  log "ydotool failed"
  exit 1
fi
date +%s%3N >"$stamp"
