#!/usr/bin/env bash
# Reap the Battle.net muvm guest. Does not touch a Steam session unless that
# session is the same leftover muvm (one guest on this machine).
set -u
killed=0
for pat in \
  'Battle.net.exe' \
  'Battle.net-Setup.exe' \
  '/teonix/battlenet/' \
  'GAMEID=battlenet' \
  '/usr/bin/muvm' \
  'muvm -- FEXBash'
do
  if pgrep -f "$pat" >/dev/null 2>&1; then
    pkill -TERM -f "$pat" 2>/dev/null || true
    killed=1
  fi
done
sleep 0.6
for pat in \
  'Battle.net.exe' \
  'Battle.net-Setup.exe' \
  'muvm -- FEXBash'
do
  pkill -KILL -f "$pat" 2>/dev/null || true
done
rm -f "${XDG_RUNTIME_DIR:-/tmp}/teonix-battlenet.lock"
if [[ $killed -eq 1 ]]; then
  echo "Battle.net / muvm signaled."
else
  echo "No Battle.net processes found."
fi
