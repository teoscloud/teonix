#!/usr/bin/env bash
# Battle.net on Fedora Asahi: 4K muvm + FEX + x86 GE-Proton. Never Steam, never
# host aarch64 Proton (RPC_S_SERVER_UNAVAILABLE hang, Proton #10011).
set -euo pipefail

# Host Fedora only. Nix Qt/Mesa/GL paths abort the FEX guest.
unset QT_PLUGIN_PATH QT_PLUGIN_PATH_1 QML2_IMPORT_PATH QML_IMPORT_PATH
unset QTWEBENGINEPROCESS_PATH QT_QPA_PLATFORM_PLUGIN_PATH QT_QPA_PLATFORMTHEME
unset LIBGL_DRIVERS_PATH GBM_BACKENDS_PATH __EGL_VENDOR_LIBRARY_FILENAMES
unset LD_LIBRARY_PATH
export PATH="/usr/bin:/usr/sbin${PATH:+:$PATH}"

PROTON_TAG=GE-Proton11-5
PROTON_TARBALL="${PROTON_TAG}-x86_64.tar.gz"
PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_TAG}/${PROTON_TARBALL}"
PROTON_SHA256=de43c4b25f3c047db49b96c44d84759952c5a01332a68805a09e69f95dc38a75

DATA="${XDG_DATA_HOME:-$HOME/.local/share}/teonix/battlenet"
COMPAT="$DATA/compat"
PROTON_DIR="$COMPAT/$PROTON_TAG"
PREFIX="$DATA/prefix"
INSTALLER_DIR="$DATA/installer"
ICONS="$DATA/icons"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
LOG="${XDG_STATE_HOME:-$HOME/.local/state}/teonix-battlenet.log"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/teonix-battlenet.lock"

mkdir -p "$COMPAT" "$PREFIX" "$INSTALLER_DIR" "$ICONS" "$(dirname "$LOG")" "$APPS"

say() { printf '%s\n' "$*"; }
log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$LOG"; }

die() {
  say "teonix-battlenet: $*" >&2
  log "error: $*"
  exit 1
}

need_muvm() {
  [[ -x /usr/bin/muvm ]] && command -v FEXBash >/dev/null || \
    die "muvm/FEXBash missing — bash ~/teonix/hosts/applenix/fedora.sh steam (installs the Asahi x86 stack, not the Steam UI)"
}

muvm_busy() {
  pgrep -x muvm >/dev/null 2>&1 \
    || pgrep -f 'muvm -- FEXBash' >/dev/null 2>&1 \
    || pgrep -f 'steamwebhelper' >/dev/null 2>&1 \
    || pgrep -f '/usr/bin/python3 /usr/bin/steam' >/dev/null 2>&1
}

find_launcher() {
  local f
  for f in \
    "$PREFIX/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net.exe" \
    "$PREFIX/drive_c/Program Files (x86)/Battle.net/Battle.net.exe" \
    "$PREFIX/pfx/drive_c/Program Files/Battle.net/Battle.net.exe" \
    "$PREFIX/drive_c/Program Files/Battle.net/Battle.net.exe"
  do
    [[ -f $f ]] && { printf '%s' "$f"; return 0; }
  done
  return 1
}

find_setup() {
  local f
  for f in \
    "$INSTALLER_DIR/Battle.net-Setup.exe" \
    "$HOME/Downloads/Battle.net-Setup.exe"
  do
    [[ -f $f ]] && { printf '%s' "$f"; return 0; }
  done
  return 1
}

stage_installer() {
  local src dest
  src=$(find_setup) || die "put Battle.net-Setup.exe in ~/Downloads (Windows x86 installer from blizzard.com)"
  dest="$INSTALLER_DIR/Battle.net-Setup.exe"
  if [[ $src != "$dest" ]]; then
    cp -f "$src" "$dest"
    log "staged installer $src -> $dest"
  fi
  printf '%s' "$dest"
}

ensure_x86_proton() {
  local wine marker tmp
  marker="$PROTON_DIR/.teonix-x86"
  wine="$PROTON_DIR/files/bin/wine"
  if [[ -x $wine && -f $marker ]]; then
    file -b "$wine" 2>/dev/null | grep -q 'x86-64' \
      || die "Proton wine is not x86_64 — delete $PROTON_DIR and retry"
    return 0
  fi

  say "Downloading $PROTON_TAG (x86_64, ~510 MiB) — not the aarch64 tarball."
  tmp=$(mktemp -d "$COMPAT/fetch.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  curl -fL --retry 3 --retry-delay 2 -o "$tmp/$PROTON_TARBALL" "$PROTON_URL" \
    || die "could not download $PROTON_URL"
  echo "$PROTON_SHA256  $tmp/$PROTON_TARBALL" | sha256sum -c - \
    || die "GE-Proton checksum mismatch — refusing to extract"
  rm -rf "$PROTON_DIR"
  mkdir -p "$PROTON_DIR"
  tar -xzf "$tmp/$PROTON_TARBALL" -C "$tmp"
  # Tarball is a single top-level directory.
  local inner
  inner=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' | head -1)
  [[ -n $inner ]] || die "unexpected Proton archive layout"
  shopt -s dotglob
  mv "$inner"/* "$PROTON_DIR/"
  shopt -u dotglob
  [[ -x $PROTON_DIR/proton && -x $wine ]] || die "extracted Proton is missing proton/wine"
  file -b "$wine" | grep -q 'x86-64' || die "downloaded Proton is not x86_64"
  date -Iseconds >"$marker"
  log "installed $PROTON_TAG x86_64 -> $PROTON_DIR"
}

mem_mib() {
  local total
  total=$(awk '/MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
  # Leave the host compositor some RAM on the 8 GB Air. Steam's 80% default OOMs here.
  local n=$((total * 50 / 100))
  if ((n < 2560)); then n=2560; fi
  if ((n > 6144)); then n=6144; fi
  printf '%s' "$n"
}

write_desktop() {
  local icon=applications-games
  local png
  png=$(find "$PREFIX" -iname 'battle.net.png' -o -iname 'battlenet.png' 2>/dev/null | head -1 || true)
  if [[ -n ${png:-} && -f $png ]]; then
    mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"
    cp -f "$png" "$HOME/.local/share/icons/hicolor/256x256/apps/battlenet.png"
    icon=battlenet
  elif [[ -f $ICONS/battlenet.png ]]; then
    mkdir -p "$HOME/.local/share/icons/hicolor/256x256/apps"
    cp -f "$ICONS/battlenet.png" "$HOME/.local/share/icons/hicolor/256x256/apps/battlenet.png"
    icon=battlenet
  fi

  cat >"$APPS/battlenet.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Battle.net
Comment=Blizzard Battle.net (teonix muvm + FEX, no Steam)
Exec=teonix-battlenet
Icon=$icon
Terminal=false
Categories=Game;
StartupWMClass=steam_app_battlenet
Keywords=blizzard;wow;warcraft;overwatch;
EOF
  rm -f "$APPS/battle-net-setup.desktop" \
        "$APPS/battle_net_setup.desktop" \
        "$HOME/.local/share/applications/Battle.net Setup.desktop"
  if command -v update-desktop-database >/dev/null; then
    update-desktop-database "$APPS" 2>/dev/null || true
  fi
  if command -v gtk-update-icon-cache >/dev/null; then
    gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
  fi
  log "published $APPS/battlenet.desktop icon=$icon"
}

# Guest env: X11 for Wine/CEF. DXVK stays on for WoW (never WineD3D — that
# aborted CEF Skia, Report 547D7067). Qt software so the launcher chrome
# does not sit on a null D3D pixmap. No Xalia, no Wayland CEF.
guest_exports() {
  cat <<'EOF'
unset QT_PLUGIN_PATH QML2_IMPORT_PATH QML_IMPORT_PATH
unset LIBGL_DRIVERS_PATH GBM_BACKENDS_PATH __EGL_VENDOR_LIBRARY_FILENAMES
unset LD_LIBRARY_PATH
unset PROTON_USE_WINED3D
export WINEDEBUG=-all
export PROTON_USE_XALIA=0
export PROTON_VERB=waitforexitandrun
export WINE_SIMULATE_WRITECOPY=1
export SDL_VIDEODRIVER=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export QT_QUICK_BACKEND=software
export QSG_RHI_BACKEND=software
export PROTON_ENABLE_WAYLAND=0
export WINEDLLOVERRIDES=winegstreamer=d;locationapi=d
export DXVK_HUD=0
EOF
}

# Blizzard stores these as strings. HardwareAcceleration=false is "Use
# browser hardware acceleration" off — not Chromium --disable-gpu.
write_client_config() {
  local cfg="$PREFIX/pfx/drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config"
  mkdir -p "$(dirname "$cfg")"
  python3 - "$cfg" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = {}
if path.exists():
    try:
        data = json.loads(path.read_text() or "{}")
    except json.JSONDecodeError:
        data = {}
client = data.setdefault("Client", {})
client["HardwareAcceleration"] = "false"
client["AutoStartMinimized"] = "false"
data.setdefault("User", {}).setdefault("Client", {})["MinimizedOnStartup"] = "false"
path.write_text(json.dumps(data, indent=4) + "\n")
PY
  log "wrote $cfg HardwareAcceleration=false"
}

guest_script() {
  local exe=$1
  shift
  local args
  args=$(printf '%q ' "$@")
  cat <<EOF
$(guest_exports)
export STEAM_COMPAT_DATA_PATH=$(printf '%q' "$PREFIX")
export STEAM_COMPAT_SHADER_PATH=$(printf '%q' "$PREFIX/shadercache")
export STEAM_COMPAT_CLIENT_INSTALL_PATH=$(printf '%q' "$DATA")
export STEAM_COMPAT_MOUNTS=$(printf '%q' "$PROTON_DIR")
export STEAM_COMPAT_TOOL_PATHS=$(printf '%q' "$PROTON_DIR")
export STEAM_COMPAT_INSTALL_PATH=$(printf '%q' "$(dirname "$exe")")
export GAMEID=battlenet
export SteamAppId=battlenet
export SteamGameId=battlenet
mkdir -p "\$STEAM_COMPAT_DATA_PATH" "\$STEAM_COMPAT_SHADER_PATH"
exec $(printf '%q' "$PROTON_DIR/proton") waitforexitandrun $(printf '%q' "$exe") $args
EOF
}

run_in_guest() {
  local exe=$1
  shift
  local mem guest
  mem=$(mem_mib)
  guest=$(guest_script "$exe" "$@")
  log "muvm mem=${mem}M exe=$exe args=$*"
  say "Starting Battle.net in muvm (${mem} MiB guest, x86 $PROTON_TAG)."
  # Do not pass -cef-force-occlusion. Force X11. One flock, one VM.
  muvm --mem="$mem" -- FEXBash -c "$guest"
}

# --- main ---

need_muvm

if [[ ${1:-} == kill ]]; then
  exec teonix-battlenet-kill
fi

if muvm_busy; then
  die "a muvm guest is already running (Steam or Battle.net). teonix-steam-kill or teonix-battlenet-kill first"
fi

exec 9>"$LOCK"
flock -n 9 || die "Battle.net is already starting"

{
  echo "==== $(date -Iseconds) pid=$$ ===="
} >>"$LOG"

ensure_x86_proton

# CEF: --disable-gpu paints a black HWND (WineHQ 57635). WineD3D GLES
# crashes Skia. ANGLE D3D11 via DXVK never blits. SwiftShader paints the
# login swirl but pegs the 8 GB guest and never begins login.app. Keep a
# GPU process (HA=false + in-process) and software-composite the HWND.
CEF_ARGS=(
  --lang=enUS
  --in-process-gpu
  --disable-gpu-compositing
  --disable-direct-composition
  --disable-gpu-sandbox
  --renderer-process-limit=1
)

launch_client() {
  local launcher=$1
  write_desktop
  write_client_config
  run_in_guest "$launcher" "${CEF_ARGS[@]}"
}

if launcher=$(find_launcher); then
  launch_client "$launcher"
  exit $?
fi

setup=$(stage_installer)
say "Battle.net is not installed yet — running the Windows setup (no language dialog)."
run_in_guest "$setup" --lang=enUS --installpath='C:\Program Files (x86)\Battle.net' "${CEF_ARGS[@]}" || true

if launcher=$(find_launcher); then
  write_desktop
  say "Setup finished. Battle.net is in the application launcher."
  for _ in $(seq 1 30); do
    muvm_busy || break
    sleep 0.4
  done
  launch_client "$launcher"
  exit $?
fi

die "setup exited without Battle.net.exe — see $LOG"
