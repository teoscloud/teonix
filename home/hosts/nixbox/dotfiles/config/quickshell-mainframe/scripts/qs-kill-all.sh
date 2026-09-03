#!/usr/bin/env bash
# Reap every Quickshell process. `pkill -x` is not enough: comm can differ
# from the argv0 nix store path, and `qs -n` would then refuse to start.
set -u

_qs_pids() {
  pgrep -x qs 2>/dev/null || true
  pgrep -x quickshell 2>/dev/null || true
  pgrep -f '/bin/quickshell([ ]|$)' 2>/dev/null || true
  pgrep -f '/quickshell([ ]|$)' 2>/dev/null || true
}

_qs_unique_pids() {
  _qs_pids | awk 'NF && $1 ~ /^[0-9]+$/ { print $1 }' | sort -u
}

for _round in 1 2 3 4 5 6 7 8; do
  _left=$(_qs_unique_pids)
  if [[ -z "${_left}" ]]; then
    exit 0
  fi
  while read -r _pid; do
    [[ -n "${_pid}" ]] || continue
    kill -TERM "${_pid}" 2>/dev/null || true
  done <<< "${_left}"
  sleep 0.15
done

_left=$(_qs_unique_pids)
if [[ -n "${_left}" ]]; then
  while read -r _pid; do
    [[ -n "${_pid}" ]] || continue
    kill -9 "${_pid}" 2>/dev/null || true
  done <<< "${_left}"
  sleep 0.2
fi

exit 0
