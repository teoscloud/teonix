#!/usr/bin/env bash
# Open cool-retro-term with the current qs-mainframe palette.
#
# cool-retro-term reads its settings DB only at startup and writes its in-memory
# copy back when a window closes, so a window that was open across a palette
# toggle would put the old colours back. Pushing the palette right before every
# launch makes each new window correct regardless of what older ones do.
set -u

mode=$(head -1 "${HOME}/.config/qs-mainframe-theme" 2>/dev/null || true)
mode=${mode//[[:space:]]/}
[[ "$mode" == dark ]] || mode=light

python3 "$(dirname "$(readlink -f "$0")")/qs-retro-term.py" "$mode" || true
exec cool-retro-term "$@"
