#!/usr/bin/env bash
# Super+mouse4/5: focus the next scrolling column, then lock the pointer to
# that window's centre. hyprctl only — bind exec must not be wrapped in `sh`
# (this file uses bash). cursor:no_warps stays on for everything else.
set -u

dir="${1:-}"
case "$dir" in
  l|r) ;;
  *) printf 'focus-column: expected l or r\n' >&2; exit 1 ;;
esac

hyprctl dispatch layoutmsg "focus $dir" >/dev/null 2>&1 || exit 1

at="" size=""
while IFS= read -r line; do
  case "$line" in
    *$'\tat: '*|*"	at: "*) at="${line#*at: }" ;;
    *$'\tsize: '*|*"	size: "*) size="${line#*size: }" ;;
  esac
done <<< "$(hyprctl activewindow 2>/dev/null)"

at="${at// /}"
size="${size// /}"
[ -n "$at" ] && [ -n "$size" ] || exit 0

aw="${size%%,*}"
ah="${size#*,}"
[ "${aw:-0}" -gt 0 ] && [ "${ah:-0}" -gt 0 ] || exit 0

cx=$((${at%%,*} + aw / 2))
cy=$((${at#*,} + ah / 2))
hyprctl dispatch -- movecursor "$cx" "$cy" >/dev/null 2>&1
