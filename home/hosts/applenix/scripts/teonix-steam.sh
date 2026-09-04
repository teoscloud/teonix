#!/usr/bin/env bash
# One muvm, no Fedora PyQt splash, no second copy.
set -euo pipefail

# Host Fedora binaries only. Nix Qt/Mesa paths make Fedora/FEX guests abort.
unset QT_PLUGIN_PATH QT_PLUGIN_PATH_1 QML2_IMPORT_PATH QML_IMPORT_PATH
unset QTWEBENGINEPROCESS_PATH QT_QPA_PLATFORM_PLUGIN_PATH QT_QPA_PLATFORMTHEME
unset LIBGL_DRIVERS_PATH GBM_BACKENDS_PATH __EGL_VENDOR_LIBRARY_FILENAMES
unset LD_LIBRARY_PATH
export PATH="/usr/bin:/usr/sbin${PATH:+:$PATH}"

if [[ ! -x /usr/bin/muvm ]] || ! command -v FEXBash >/dev/null; then
  echo "muvm/FEXBash missing — bash ~/teonix/hosts/applenix/fedora.sh steam" >&2
  exit 1
fi

runtime="${XDG_RUNTIME_DIR:-/tmp}"
lock="$runtime/teonix-steam.lock"
log="${XDG_STATE_HOME:-$HOME/.local/state}/teonix-steam.log"
mkdir -p "$(dirname "$log")"

already_up() {
  pgrep -x muvm >/dev/null 2>&1 \
    || pgrep -f 'muvm -- FEXBash' >/dev/null 2>&1 \
    || pgrep -f 'steamwebhelper' >/dev/null 2>&1 \
    || pgrep -f '/usr/bin/python3 /usr/bin/steam' >/dev/null 2>&1
}

if already_up; then
  echo "Steam is already running — not starting another muvm." >&2
  exit 0
fi

exec 9>"$lock"
if ! flock -n 9; then
  echo "Steam is already running — not starting another muvm." >&2
  exit 0
fi

# Re-check after the lock: a leftover guest from the old wrapper has no flock.
if already_up; then
  echo "Steam is already running — not starting another muvm." >&2
  exit 0
fi

# Prefer the bootstrapped client. bin_steam.sh re-extracts and looks like a loop.
if [[ -f $HOME/.local/share/Steam/steam.sh ]]; then
  launcher=$HOME/.local/share/Steam/steam.sh
elif [[ -f $HOME/.local/share/fex-steam/steam-launcher/bin_steam.sh ]]; then
  launcher=$HOME/.local/share/fex-steam/steam-launcher/bin_steam.sh
else
  echo "Steam client is not bootstrapped — falling back to /usr/bin/steam" >&2
  exec /usr/bin/steam "$@"
fi

{
  echo "==== $(date -Iseconds) launcher=$launcher args=$* ===="
} >>"$log"

# Do not pass -cef-force-occlusion: it was for Big Picture and makes CEF
# treat the window as hidden, which restarts steamwebhelper in a loop.
cmd=$(printf '%q ' "$launcher" "$@")
exec muvm -- FEXBash -c "$cmd" >>"$log" 2>&1
