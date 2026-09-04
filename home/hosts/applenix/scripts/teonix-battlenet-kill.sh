#!/usr/bin/env bash
# Reap the Battle.net / WoW muvm guest. Does not spare a leftover Steam muvm
# (one guest on this machine).
#
# There is no host-side "wineserver -k": wineserver is an x86_64 binary that
# needs the guest's 4K pages, and killing the muvm VM tears the whole Wine
# session down with it anyway.
set -u
me=$$
pp=${PPID:-0}
killed=0
kill_pat() {
  local sig=$1 pat=$2 pid
  while read -r pid; do
    [[ -z $pid || $pid == "$me" || $pid == "$pp" ]] && continue
    kill -"$sig" "$pid" 2>/dev/null || true
    killed=1
  done < <(pgrep -f "$pat" || true)
}
for pat in \
  '[Ww]o[Ww]Classic.exe' \
  'Battle.net.exe' \
  'Battle.net-Setup.exe' \
  '/teonix/home/hosts/applenix/scripts/teonix-wow.sh' \
  '/teonix/home/hosts/applenix/scripts/teonix-battlenet.sh' \
  '/scripts/teonix-wow.sh' \
  '/scripts/teonix-battlenet.sh' \
  '/teonix/battlenet/' \
  'GAMEID=battlenet' \
  '/usr/bin/muvm' \
  'muvm -- FEXBash' \
  'muvm --mem'
do
  kill_pat TERM "$pat"
done
sleep 0.6
for pat in \
  '[Ww]o[Ww]Classic.exe' \
  'Battle.net.exe' \
  'Battle.net-Setup.exe' \
  'muvm -- FEXBash' \
  'muvm --mem'
do
  kill_pat KILL "$pat"
done
# The VM renames itself to "libkrun VM", so the patterns above can miss it.
# /proc/PID/exe survives the rename.
for dir in /proc/[0-9]*; do
  case $(readlink "$dir/exe" 2>/dev/null) in
    */muvm)
      pid=${dir#/proc/}
      [[ $pid == "$me" || $pid == "$pp" ]] && continue
      kill -KILL "$pid" 2>/dev/null || true
      killed=1
      ;;
  esac
done
data="${XDG_DATA_HOME:-$HOME/.local/share}/teonix/battlenet"
rm -f \
  "${XDG_RUNTIME_DIR:-/tmp}/teonix-muvm.lock" \
  "${XDG_RUNTIME_DIR:-/tmp}/teonix-battlenet.lock" \
  "${XDG_RUNTIME_DIR:-/tmp}/teonix-wowup.lock" \
  "${XDG_RUNTIME_DIR:-/tmp}/teonix-bnet-checkpoint.seen" \
  "${XDG_RUNTIME_DIR:-/tmp}/teonix-bnet-st.seen" \
  "$data/inject-st.url" \
  "$data/start-wow" \
  "$data/rescue-wow" \
  "$data/prefix/pfx/drive_c/teonix-start-wow"
if [[ $killed -eq 1 ]]; then
  echo "Battle.net / WoW / muvm signaled."
else
  echo "No Battle.net processes found."
fi
