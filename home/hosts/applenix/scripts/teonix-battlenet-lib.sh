# Shared Battle.net / WoW Classic prefix + frozen CEF path. Sourced, not exec'd.
# shellcheck shell=bash

PROTON_TAG=GE-Proton11-5
PROTON_TARBALL="${PROTON_TAG}-x86_64.tar.gz"
PROTON_URL="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_TAG}/${PROTON_TARBALL}"
PROTON_SHA256=de43c4b25f3c047db49b96c44d84759952c5a01332a68805a09e69f95dc38a75

# Frozen. Do not add --disable-gpu, WineD3D, SwiftShader, or ANGLE D3D11.
# --disable-gpu is a black HWND. WineD3D crashes Skia. SwiftShader never
# starts login.app. ANGLE D3D11 never blits. HardwareAcceleration=false is
# the Blizzard setting, not a Chromium flag.
CEF_ARGS=(
  --lang=enUS
  --in-process-gpu
  --disable-gpu-compositing
  --disable-direct-composition
  --disable-gpu-sandbox
  --renderer-process-limit=1
)

DATA="${XDG_DATA_HOME:-$HOME/.local/share}/teonix/battlenet"
COMPAT="$DATA/compat"
PROTON_DIR="$COMPAT/$PROTON_TAG"
PREFIX="$DATA/prefix"
INSTALLER_DIR="$DATA/installer"
ICONS="$DATA/icons"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
BNET_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/teonix-battlenet.log"
BNET_USER_LOGS="$PREFIX/pfx/drive_c/users/steamuser/AppData/Local/Battle.net/Logs"
WOW_CLASSIC_DIR="$PREFIX/pfx/drive_c/Program Files (x86)/World of Warcraft/_anniversary_"
WOW_CLASSIC_EXE="$WOW_CLASSIC_DIR/WowClassic.exe"
INJECT_ST="$DATA/inject-st.url"
GUEST_BIN="$DATA/guest-bin"

mkdir -p "$COMPAT" "$PREFIX" "$INSTALLER_DIR" "$ICONS" "$(dirname "$BNET_LOG")" "$APPS"

bnet_log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$BNET_LOG"; }

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
  src=$(find_setup) || {
    echo "teonix: put Battle.net-Setup.exe in ~/Downloads (Windows x86 installer from blizzard.com)" >&2
    return 1
  }
  dest="$INSTALLER_DIR/Battle.net-Setup.exe"
  if [[ $src != "$dest" ]]; then
    cp -f "$src" "$dest"
    bnet_log "staged installer $src -> $dest"
  fi
  printf '%s' "$dest"
}

ensure_x86_proton() {
  local wine marker tmp inner
  marker="$PROTON_DIR/.teonix-x86"
  wine="$PROTON_DIR/files/bin/wine"
  if [[ -x $wine && -f $marker ]]; then
    file -b "$wine" 2>/dev/null | grep -q 'x86-64' \
      || { echo "teonix: Proton wine is not x86_64 — delete $PROTON_DIR" >&2; return 1; }
    return 0
  fi

  echo "Downloading $PROTON_TAG (x86_64, ~510 MiB) — not the aarch64 tarball."
  tmp=$(mktemp -d "$COMPAT/fetch.XXXXXX")
  # shellcheck disable=SC2064
  trap "rm -rf '$tmp'" RETURN
  curl -fL --retry 3 --retry-delay 2 -o "$tmp/$PROTON_TARBALL" "$PROTON_URL" || return 1
  echo "$PROTON_SHA256  $tmp/$PROTON_TARBALL" | sha256sum -c - || return 1
  rm -rf "$PROTON_DIR"
  mkdir -p "$PROTON_DIR"
  tar -xzf "$tmp/$PROTON_TARBALL" -C "$tmp"
  inner=$(find "$tmp" -mindepth 1 -maxdepth 1 -type d -name 'GE-Proton*' | head -1)
  [[ -n $inner ]] || return 1
  shopt -s dotglob
  mv "$inner"/* "$PROTON_DIR/"
  shopt -u dotglob
  [[ -x $PROTON_DIR/proton && -x $wine ]] || return 1
  file -b "$wine" | grep -q 'x86-64' || return 1
  date -Iseconds >"$marker"
  bnet_log "installed $PROTON_TAG x86_64 -> $PROTON_DIR"
  trap - RETURN
  rm -rf "$tmp"
}

mem_mib() {
  local total n
  total=$(awk '/MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
  if find_launcher >/dev/null; then
    n=$((total * 55 / 100))
    if ((n < 3600)); then n=3600; fi
  else
    n=$((total * 50 / 100))
    if ((n < 2560)); then n=2560; fi
  fi
  if ((n > 6144)); then n=6144; fi
  printf '%s' "$n"
}

# Wow + Battle.net CEF in one 4 GiB guest leaves the host with ~600 MiB.
# XWayland then never maps WowClassic and Play returns. Cap the guest.
wow_mem_mib() {
  local total n
  total=$(awk '/MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
  n=$((total * 40 / 100))
  if ((n < 2560)); then n=2560; fi
  if ((n > 3072)); then n=3072; fi
  printf '%s' "$n"
}

write_desktop() {
  local icon=applications-games png
  # Do not walk the 7+ GiB WoW tree for an icon.
  png=""
  local dir
  for dir in \
    "$PREFIX/pfx/drive_c/Program Files (x86)/Battle.net" \
    "$PREFIX/drive_c/Program Files (x86)/Battle.net" \
    "$PREFIX/pfx/drive_c/Program Files/Battle.net" \
    "$ICONS"
  do
    [[ -d $dir ]] || continue
    png=$(find "$dir" -maxdepth 4 \( -iname 'battle.net.png' -o -iname 'battlenet.png' \) 2>/dev/null | head -1 || true)
    [[ -n ${png:-} ]] && break
  done
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
  command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" 2>/dev/null || true
  command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -f "$HOME/.local/share/icons/hicolor" 2>/dev/null || true
  bnet_log "published $APPS/battlenet.desktop icon=$icon"
}

# Guest env: X11 for Wine/CEF. DXVK stays on for WowClassic (never WineD3D —
# that aborted CEF Skia, Report 547D7067). Qt software so launcher chrome
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
export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0
EOF
}

compat_exports() {
  local exe=${1:-}
  cat <<EOF
export STEAM_COMPAT_DATA_PATH=$(printf '%q' "$PREFIX")
export STEAM_COMPAT_SHADER_PATH=$(printf '%q' "$PREFIX/shadercache")
export STEAM_COMPAT_CLIENT_INSTALL_PATH=$(printf '%q' "$DATA")
export STEAM_COMPAT_MOUNTS=$(printf '%q' "$PROTON_DIR")
export STEAM_COMPAT_TOOL_PATHS=$(printf '%q' "$PROTON_DIR")
export GAMEID=battlenet
export SteamAppId=battlenet
export SteamGameId=battlenet
export PATH=$(printf '%q' "$GUEST_BIN"):"\$PATH"
export BROWSER=$(printf '%q' "$GUEST_BIN/xdg-open")
mkdir -p "\$STEAM_COMPAT_DATA_PATH" "\$STEAM_COMPAT_SHADER_PATH" $(printf '%q' "$GUEST_BIN")
EOF
  if [[ -n $exe ]]; then
    printf 'export STEAM_COMPAT_INSTALL_PATH=%q\n' "$(dirname "$exe")"
  fi
}

# Wine's winebrowser calls xdg-open. localhost:0?ST= is the launcher callback —
# never send it to Brave (ERR_UNSAFE_PORT). Checkpoint HTTPS stays in CEF.
install_guest_xdg_open() {
  mkdir -p "$GUEST_BIN"
  cat >"$GUEST_BIN/xdg-open" <<EOF
#!/bin/bash
url=\${1:-}
case \$url in
  http://localhost:*|http://127.0.0.1:*|https://localhost:*|https://127.0.0.1:*)
    case \$url in
      *ST=*) printf '%s\\n' "\$url" > $(printf '%q' "$INJECT_ST") ;;
    esac
    exit 0
    ;;
  *token-security-checkpoint*|*account.battle.net/login/challenge*)
    exit 0
    ;;
esac
exec /usr/bin/xdg-open "\$@"
EOF
  chmod +x "$GUEST_BIN/xdg-open"
}

inject_sidecar() {
  local launcher=$1
  cat <<EOF
(
  while true; do
    sleep 2
    [[ -s $(printf '%q' "$INJECT_ST") ]] || continue
    url=\$(head -1 $(printf '%q' "$INJECT_ST") || true)
    rm -f $(printf '%q' "$INJECT_ST")
    case \$url in *ST=*) ;; *) continue ;; esac
    echo "teonix: handing the session ticket back to Battle.net (not Brave)."
    PROTON_VERB=run $(printf '%q' "$PROTON_DIR/proton") run $(printf '%q' "$launcher") "\$url" || true
  done
) &
EOF
}

guest_script() {
  local exe=$1
  shift
  local args
  args=$(printf '%q ' "$@")
  cat <<EOF
$(guest_exports)
$(compat_exports "$exe")
$(inject_sidecar "$exe")
exec $(printf '%q' "$PROTON_DIR/proton") waitforexitandrun $(printf '%q' "$exe") $args
EOF
}

run_in_guest() {
  local exe=$1
  shift
  local mem guest
  mem=$(mem_mib)
  install_guest_xdg_open
  guest=$(guest_script "$exe" "$@")
  bnet_log "muvm mem=${mem}M exe=$exe args=$*"
  echo "Starting in muvm (${mem} MiB guest, x86 $PROTON_TAG). Log: $BNET_LOG"
  echo "Stay in the Battle.net window. Do not finish login in Brave — localhost:0 is the callback, not a website."
  muvm --mem="$mem" -- FEXBash -c "$guest"
}

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
  bnet_log "wrote $cfg HardwareAcceleration=false"
}

write_wow_classic_config() {
  local wtf="$WOW_CLASSIC_DIR/WTF"
  local cfg="$wtf/Config.wtf"
  [[ -d $WOW_CLASSIC_DIR ]] || return 0
  mkdir -p "$wtf"
  cat >"$cfg" <<'EOF'
SET gxApi "D3D11"
SET gxWindow "1"
SET gxMaximize "0"
SET gxFullscreen "0"
SET gxResolution "1600x1000"
SET gxWindowedResolution "1600x1000"
SET hwDetect "0"
SET vsync "0"
EOF
  bnet_log "wrote $cfg windowed D3D11 1600x1000"
}

# Host-side: never xdg-open the challenge. Completing it in Brave ends at
# localhost:0?ST= (ERR_UNSAFE_PORT) and Battle.net never sees the ticket.
# If Brave already has that tab, steal ST= and hand it to the guest CEF.
scrape_brave_st() {
  python3 - <<'PY'
from pathlib import Path
import re
pat = re.compile(
    rb"http://localhost:0/\?ST=[A-Z]{2}-[A-Za-z0-9-]+(?:&[A-Za-z0-9_]+=[^&\x00-\x20]*)*"
)
roots = [
    Path.home() / ".config/BraveSoftware/Brave-Browser/Default",
    Path.home() / ".config/BraveSoftware/Brave-Browser/Default/Sessions",
]
found = []
for root in roots:
    if not root.exists():
        continue
    files = [root] if root.is_file() else list(root.iterdir())
    for f in files:
        if not f.is_file():
            continue
        try:
            data = f.read_bytes()
        except OSError:
            continue
        for m in pat.finditer(data):
            found.append(m.group().decode("ascii", "ignore"))
if found:
    print(found[-1])
PY
}

write_inject_st() {
  local url=${1:-}
  [[ $url == *ST=* ]] || return 1
  printf '%s\n' "$url" >"$INJECT_ST"
  bnet_log "queued session ticket for Battle.net (host browser callback)"
  echo "teonix: got the login ticket from Brave. Close the ERR_UNSAFE_PORT tab — Battle.net will finish sign-in."
}

teonix_bnet_auth() {
  local url=${1:-}
  if [[ -z $url || $url == --brave ]]; then
    url=$(scrape_brave_st || true)
  fi
  if [[ -z ${url:-} ]]; then
    echo "teonix: no localhost:0?ST= ticket found. Copy the Brave address bar and run:" >&2
    echo "  teonix-battlenet auth 'http://localhost:0/?ST=...'" >&2
    return 1
  fi
  write_inject_st "$url"
}

# Background watcher. Do not capture this with $() — the loop must not inherit
# that pipe or the launcher blocks forever on anon_pipe_read. Caller: watch_checkpoint; watch_pid=$!
watch_checkpoint() {
  local seen="${XDG_RUNTIME_DIR:-/tmp}/teonix-bnet-checkpoint.seen"
  local st_seen="${XDG_RUNTIME_DIR:-/tmp}/teonix-bnet-st.seen"
  : >"$seen"
  : >"$st_seen"
  (
    local warned=0
    while true; do
      sleep 2
      local f url st
      f=$(ls -t "$BNET_USER_LOGS"/battle.net-*.log 2>/dev/null | head -1) || true
      if [[ -n ${f:-} ]]; then
        url=$(grep -oE 'https://[^[:space:]]+token-security-checkpoint[^[:space:]]*' "$f" 2>/dev/null | tail -1) || true
        if [[ -n ${url:-} ]] && ! grep -qxF "$url" "$seen" 2>/dev/null; then
          printf '%s\n' "$url" >>"$seen"
          if [[ $warned -eq 0 ]]; then
            echo "teonix: security checkpoint is in the Battle.net window. Do not finish it in Brave." >&2
            echo "teonix: Brave localhost:0 is ERR_UNSAFE_PORT — that ticket has to go back to the launcher." >&2
            warned=1
          fi
        fi
      fi
      st=$(scrape_brave_st || true)
      if [[ -n ${st:-} ]] && ! grep -qxF "$st" "$st_seen" 2>/dev/null; then
        printf '%s\n' "$st" >>"$st_seen"
        write_inject_st "$st" >&2
      fi
    done
  ) >>"$BNET_LOG" 2>&1 &
}
