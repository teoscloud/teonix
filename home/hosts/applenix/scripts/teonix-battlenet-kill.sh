#!/usr/bin/env bash
# Reap the Battle.net / WoW muvm guest. Does not spare a leftover Steam muvm
# (one guest on this machine).
set -u
me=$$
pp=${PPID:-0}
killed=0
kill_pat() {
  local sig=$1 pat=$2 pid
  while read -r pid; do
    [[ -z $pid || $pid == "$me" || $pid == "$pp" ]] && continue
    kill -$sig "$pid" 2>/dev/null || true
    killed=1
  done < <(pgrep -f "$pat" || true)
}
for pat in \
  'WowClassic.exe' \
  'Battle.net.exe' \
  'Battle.net-Setup.exe' \
  '/teonix/home/hosts/applenix/scripts/teonix-wow.sh' \
  '/teonix/home/hosts/applenix/scripts/teonix-battlenet.sh' \
  '/scripts/teonix-wow.sh' \
  '/scripts/teonix-battlenet.sh' \
  '/teonix/battlenet/' \
  'GAMEID=battlenet' \
  '/usr/bin/muvm' \
  'muvm -- FEXBash'
do
  kill_pat TERM "$pat"
done
sleep 0.6
for pat in \
  'WowClassic.exe' \
  'Battle.net.exe' \
  'Battle.net-Setup.exe' \
  'muvm -- FEXBash'
do
  kill_pat KILL "$pat"
done
rm -f \
  "${XDG_RUNTIME_DIR:-/tmp}/teonix-muvm.lock" \
  "${XDG_RUNTIME_DIR:-/tmp}/teonix-battlenet.lock" \
  "${XDG_RUNTIME_DIR:-/tmp}/teonix-wowup.lock" \
  "${XDG_RUNTIME_DIR:-/tmp}/teonix-bnet-checkpoint.seen" \
  "${XDG_RUNTIME_DIR:-/tmp}/teonix-bnet-st.seen"
if [[ $killed -eq 1 ]]; then
  echo "Battle.net / WoW / muvm signaled."
else
  echo "No Battle.net processes found."
fi
