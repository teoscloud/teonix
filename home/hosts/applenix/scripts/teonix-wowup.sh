#!/usr/bin/env bash
# WowUp.CF on Fedora Asahi: official x86_64 AppImage in a 4K muvm + FEX.
# nixpkgs wowup-cf is x86_only and cannot go in aarch64 home.packages.
set -euo pipefail

unset QT_PLUGIN_PATH QT_PLUGIN_PATH_1 QML2_IMPORT_PATH QML_IMPORT_PATH
unset QTWEBENGINEPROCESS_PATH QT_QPA_PLATFORM_PLUGIN_PATH QT_QPA_PLATFORMTHEME
unset LIBGL_DRIVERS_PATH GBM_BACKENDS_PATH __EGL_VENDOR_LIBRARY_FILENAMES
unset LD_LIBRARY_PATH
export PATH="/usr/bin:/usr/sbin${PATH:+:$PATH}"

APPIMAGE="${TEONIX_WOWUP_APPIMAGE:-}"
DATA="${XDG_DATA_HOME:-$HOME/.local/share}/teonix/wowup"
ROOT="$DATA/squashfs-root"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/teonix-wowup.log"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/teonix-wowup.lock"
WOW_PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}/teonix/battlenet/prefix/pfx/drive_c/Program Files (x86)/World of Warcraft"

mkdir -p "$DATA" "$(dirname "$LOG")"

say() { printf '%s\n' "$*"; }
log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$LOG"; }

die() {
  say "teonix-wowup: $*" >&2
  log "error: $*"
  exit 1
}

need_muvm() {
  [[ -x /usr/bin/muvm ]] && command -v FEXBash >/dev/null || \
    die "muvm/FEXBash missing — bash ~/teonix/hosts/applenix/fedora.sh steam"
}

muvm_busy() {
  pgrep -x muvm >/dev/null 2>&1 \
    || pgrep -f 'muvm -- FEXBash' >/dev/null 2>&1 \
    || pgrep -f 'steamwebhelper' >/dev/null 2>&1 \
    || pgrep -f '/usr/bin/python3 /usr/bin/steam' >/dev/null 2>&1
}

mem_mib() {
  local total n
  total=$(awk '/MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
  n=$((total * 40 / 100))
  if ((n < 2048)); then n=2048; fi
  if ((n > 4096)); then n=4096; fi
  printf '%s' "$n"
}

hint_wow_clients() {
  say "In WowUp → Add client, use this folder (Wine prefix, not a Windows C: path):"
  say "  $WOW_PREFIX"
  if [[ -d $WOW_PREFIX ]]; then
    local d
    for d in "$WOW_PREFIX"/_retail_ "$WOW_PREFIX"/_classic_ "$WOW_PREFIX"/_classic_era_ "$WOW_PREFIX"/_classic_ptr_ "$WOW_PREFIX"/_beta_; do
      [[ -d $d ]] && say "  found $(basename "$d")"
    done
  else
    say "  (WoW is not installed there yet — finish the Battle.net install first)"
  fi
}

[[ -n $APPIMAGE && -f $APPIMAGE ]] || \
  die "WowUp AppImage missing — updatehome (TEONIX_WOWUP_APPIMAGE)"

need_muvm

if muvm_busy; then
  die "a muvm guest is already running (Battle.net or Steam). teonix-battlenet-kill first — one guest on this machine"
fi

exec 9>"$LOCK"
flock -n 9 || die "WowUp is already starting"

{
  echo "==== $(date -Iseconds) pid=$$ ===="
} >>"$LOG"

hint_wow_clients

local_image="$DATA/WowUp-CF.AppImage"
if [[ ! -f $local_image ]] || ! cmp -s "$APPIMAGE" "$local_image"; then
  cp -f "$APPIMAGE" "$local_image"
  chmod +x "$local_image"
  rm -rf "$ROOT"
  log "staged AppImage -> $local_image"
fi

mem=$(mem_mib)
extract_and_run=$(cat <<EOF
unset QT_PLUGIN_PATH QML2_IMPORT_PATH QML_IMPORT_PATH
unset LIBGL_DRIVERS_PATH GBM_BACKENDS_PATH __EGL_VENDOR_LIBRARY_FILENAMES
unset LD_LIBRARY_PATH
export SDL_VIDEODRIVER=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export ELECTRON_OZONE_PLATFORM_HINT=x11
cd $(printf '%q' "$DATA")
if [[ ! -x squashfs-root/AppRun ]]; then
  ./WowUp-CF.AppImage --appimage-extract
fi
exec ./squashfs-root/AppRun --no-sandbox --ozone-platform=x11
EOF
)

log "muvm mem=${mem}M appimage=$local_image"
say "Starting WowUp.CF in muvm (${mem} MiB guest, x86 AppImage)."
muvm --mem="$mem" -- FEXBash -c "$extract_and_run"
