#!/usr/bin/env bash
# Reap Steam + muvm leftovers. Safe to run when Steam is wedged.
set -u
killed=0
for pat in \
  '/usr/bin/muvm' \
  'muvm -- FEXBash' \
  'bin_steam\.sh' \
  '/Steam/steam.sh' \
  'steamwebhelper' \
  '/usr/bin/python3 /usr/bin/steam'
do
  if pgrep -f "$pat" >/dev/null 2>&1; then
    pkill -TERM -f "$pat" 2>/dev/null || true
    killed=1
  fi
done
sleep 0.6
for pat in \
  'muvm -- FEXBash' \
  'steamwebhelper' \
  '/usr/bin/python3 /usr/bin/steam'
do
  pkill -KILL -f "$pat" 2>/dev/null || true
done
rm -f "${XDG_RUNTIME_DIR:-/tmp}/teonix-steam.lock"
if [[ $killed -eq 1 ]]; then
  echo "Steam processes signaled."
else
  echo "No Steam processes found."
fi
