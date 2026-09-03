#!/usr/bin/env bash
# Align GTK / portal color-scheme with the mainframe palette (light|dark).
# Cursor theme is left alone.
set -euo pipefail

mode=${1:-}
if [[ "$mode" != light && "$mode" != dark ]]; then
  raw=$(head -1 "${HOME}/.config/qs-mainframe-theme" 2>/dev/null || true)
  mode=${raw%%$'\n'*}
  mode=${mode//[[:space:]]/}
fi
[[ "$mode" == dark ]] || mode=light

if [[ "$mode" == dark ]]; then
  scheme=prefer-dark
  gtk=WhiteSur-Dark
  prefer=true
else
  scheme=prefer-light
  gtk=WhiteSur-Light
  prefer=false
fi

gsettings set org.gnome.desktop.interface color-scheme "$scheme" || true
gsettings set org.gnome.desktop.interface gtk-theme "$gtk" || true
gsettings set org.gnome.desktop.interface gtk-application-prefer-dark-theme "$prefer" 2>/dev/null || true
