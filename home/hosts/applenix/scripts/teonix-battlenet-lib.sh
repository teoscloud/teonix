# Shared Battle.net / WoW Classic prefix + frozen CEF path. Sourced, not exec'd.
# Requires teonix-muvm-common.sh to be sourced first (teonix_muvm_pid).
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

WOW_UID=wow_classic_anniversary

DATA="${XDG_DATA_HOME:-$HOME/.local/share}/teonix/battlenet"
COMPAT="$DATA/compat"
PROTON_DIR="$COMPAT/$PROTON_TAG"
WINESERVER="$PROTON_DIR/files/bin/wineserver"
PREFIX="$DATA/prefix"
INSTALLER_DIR="$DATA/installer"
ICONS="$DATA/icons"
BNET_LOG="${XDG_STATE_HOME:-$HOME/.local/state}/teonix-battlenet.log"
BNET_USER_LOGS="$PREFIX/pfx/drive_c/users/steamuser/AppData/Local/Battle.net/Logs"
WOW_CLASSIC_DIR="$PREFIX/pfx/drive_c/Program Files (x86)/World of Warcraft/_anniversary_"
WOW_CLASSIC_EXE="$WOW_CLASSIC_DIR/WowClassic.exe"
GUEST_BIN="$DATA/guest-bin"
GUEST_DIR="$DATA/guest"
CACHE_DIR="$DATA/cache"
DXVK_CONF="$DATA/dxvk.conf"
# Host -> guest one-shot rescue signal. Shared home, so the guest sees it.
RETRY_FLAG="$DATA/rescue-wow"

mkdir -p "$COMPAT" "$PREFIX" "$INSTALLER_DIR" "$ICONS" "$GUEST_DIR" \
  "$CACHE_DIR/dxvk" "$CACHE_DIR/mesa" "$(dirname "$BNET_LOG")"

bnet_log() { printf '%s %s\n' "$(date -Iseconds)" "$*" >>"$BNET_LOG"; }

# Greppable session verdicts: RESULT: ok | no-window | launcher-crash.
bnet_result() {
  local verdict=$1
  shift
  printf '%s RESULT: %s %s\n' "$(date -Iseconds)" "$verdict" "$*" >>"$BNET_LOG"
}

bnet_notify() {
  command -v notify-send >/dev/null 2>&1 || return 0
  notify-send -a "Battle.net" "$1" "${2:-}" >/dev/null 2>&1 || true
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

# muvm --mem is a ceiling, not a reservation: "memory ... will not be reserved
# immediately ... provided as the guest demands it, and both the guest and
# libkrun will attempt to return as many pages as possible to the host".
# A low ceiling therefore protects nothing and only guarantees an in-guest OOM
# when Play spawns WowClassic next to CEF (~1.2G + ~2.5G + Wine/FEX/DXVK).
mem_mib() {
  local total n
  total=$(awk '/MemTotal:/ { print int($2 / 1024) }' /proc/meminfo)
  n=$((total * 85 / 100))
  if ((n < 3584)); then n=3584; fi
  printf '%s' "$n"
}

# Reported to userspace as the GPU heap. Left at muvm's 50%-of-RAM default,
# DXVK advertises far more VRAM than this unified-memory box can back.
vram_mib() {
  local mem=${1:-0} n=2048
  if ((mem > 0 && n > mem / 2)); then n=$((mem / 2)); fi
  printf '%s' "$n"
}

ram_report() {
  local avail swap
  avail=$(awk '/MemAvailable:/ { print int($2 / 1024) }' /proc/meminfo)
  swap=$(awk '/SwapFree:/ { print int($2 / 1024) }' /proc/meminfo)
  echo "RAM: ${avail} MiB available, ${swap} MiB swap free. WoW + launcher wants ~4500 MiB."
  if ((avail < 4500)); then
    echo "Biggest processes right now (close one if WoW stutters):"
    ps -eo rss,comm --sort=-rss --no-headers 2>/dev/null \
      | awk 'NR<=4 { printf "  %-24s %d MiB\n", $2, $1 / 1024 }'
  fi
}

# Guest env: X11 for Wine/CEF. DXVK stays on for WowClassic (never WineD3D —
# that aborted CEF Skia, Report 547D7067). Qt software so launcher chrome
# does not sit on a null D3D pixmap. No Xalia, no Wayland CEF.
guest_env_block() {
  cat <<'EOF'
unset QT_PLUGIN_PATH QML2_IMPORT_PATH QML_IMPORT_PATH
unset LIBGL_DRIVERS_PATH GBM_BACKENDS_PATH __EGL_VENDOR_LIBRARY_FILENAMES
unset LD_LIBRARY_PATH
unset PROTON_USE_WINED3D
export WINEDEBUG=-all
export PROTON_USE_XALIA=0
export PROTON_VERB=waitforexitandrun
export WINE_SIMULATE_WRITECOPY=1
export DISPLAY="${DISPLAY:-:0}"
export SDL_VIDEODRIVER=x11
export GDK_BACKEND=x11
export QT_QPA_PLATFORM=xcb
export QT_QUICK_BACKEND=software
export QSG_RHI_BACKEND=software
export PROTON_ENABLE_WAYLAND=0
export DXVK_HUD=0
export SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0
EOF
  # Quoted: the semicolon used to split this into two commands, silently
  # dropping the locationapi override.
  printf 'export WINEDLLOVERRIDES=%q\n' 'winegstreamer=d;locationapi=d'
  printf 'export DXVK_CONFIG_FILE=%q\n' "$DXVK_CONF"
  printf 'export DXVK_STATE_CACHE_PATH=%q\n' "$CACHE_DIR/dxvk"
  printf 'export MESA_SHADER_CACHE_DIR=%q\n' "$CACHE_DIR/mesa"
  # WINEDEBUG=-all is right for daily use and useless when a launch hangs
  # with no window and no log. TEONIX_BNET_DEBUG=1 gets Proton to talk.
  if [[ ${TEONIX_BNET_DEBUG:-0} == 1 ]]; then
    mkdir -p "$DATA/logs"
    printf 'export PROTON_LOG_DIR=%q\n' "$DATA/logs"
    echo 'export PROTON_LOG=1'
    echo 'export WINEDEBUG=err+all,fixme-all'
    echo 'export DXVK_LOG_LEVEL=info'
    printf 'export DXVK_LOG_PATH=%q\n' "$DATA/logs"
  fi
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

# Never open a host browser. winebrowser/xdg-open stays inside the guest.
install_guest_xdg_open() {
  mkdir -p "$GUEST_BIN"
  cat >"$GUEST_BIN/xdg-open" <<'EOF'
#!/bin/bash
exit 0
EOF
  chmod +x "$GUEST_BIN/xdg-open"
}

write_dxvk_conf() {
  cat >"$DXVK_CONF" <<'EOF'
# Four performance cores shared with FEX: a compile storm on login stalls
# the game and spikes guest memory.
dxvk.numCompilerThreads = 2
dxgi.maxDeviceMemory = 2048
dxgi.maxSharedMemory = 2048
EOF
}

# Logical desktop size for the launcher's virtual desktop, minus a margin so
# the window stays grabbable.
screen_desktop_size() {
  local size
  size=$(hyprctl monitors -j 2>/dev/null | python3 -c '
import json, sys
try:
    ms = json.load(sys.stdin)
except Exception:
    raise SystemExit
if not ms:
    raise SystemExit
m = ms[0]
scale = float(m.get("scale") or 1) or 1
w = int(int(m.get("width") or 0) / scale) - 64
h = int(int(m.get("height") or 0) / scale) - 100
if w < 1280:
    w = 1280
if h < 800:
    h = 800
print(f"{w}x{h}")
' 2>/dev/null || true)
  printf '%s' "${size:-1536x900}"
}

# The virtual desktop is what guarantees CEF an HWND on XWayland, but a
# prefix-wide Software\Wine\Explorer\Desktop boxes WowClassic inside the
# launcher's window too. Scope it to Battle.net.exe via AppDefaults so the
# game gets a native window.
write_wine_registry() {
  local reg="$PREFIX/pfx/user.reg" size
  [[ -f $reg ]] || return 0
  size=$(screen_desktop_size)
  # Section rewrite, never re.sub: a backslash-bearing replacement string gets
  # its escapes interpreted, so [Software\\Wine\\Explorer] halved its
  # backslashes on every pass and eventually left junk keys like
  # [SoftwareWineExplorer] behind, each still carrying a global "Desktop".
  python3 - "$reg" "$size" <<'PY'
from pathlib import Path
import sys
import time

path = Path(sys.argv[1])
size = sys.argv[2]
ts = int(time.time())

# Dropped wholesale before the canonical copies are appended, so duplicates
# cannot survive. Compared with the separators stripped, because earlier
# passes left half-escaped ([Software\Wine\Explorer]) and fully stripped
# ([SoftwareWineExplorer]) spellings of the same keys in the file.
def norm(header):
    return header.replace("\\", "").lower()


managed = {
    norm(h)
    for h in (
        "[Software\\\\Wine\\\\Explorer]",
        "[Software\\\\Wine\\\\Explorer\\\\Desktops]",
        "[Software\\\\Wine\\\\AppDefaults\\\\Battle.net.exe\\\\Explorer]",
    )
}

canonical = [
    # Named size map. No "Desktop" under Software\Wine\Explorer itself:
    # prefix-wide, it would box WowClassic inside the launcher's desktop.
    ("[Software\\\\Wine\\\\Explorer\\\\Desktops]", [f'"Battle.net"="{size}"']),
    ("[Software\\\\Wine\\\\AppDefaults\\\\Battle.net.exe\\\\Explorer]", ['"Desktop"="Battle.net"']),
]

out = []
skipping = False
for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
    if line.startswith("["):
        header = line[: line.rindex("]") + 1] if "]" in line else line
        skipping = norm(header) in managed
    if not skipping:
        out.append(line)

while out and not out[-1].strip():
    out.pop()

for header, body in canonical:
    out.append("")
    out.append(f"{header} {ts}")
    out.append("#time=0")
    out.extend(body)

path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
  bnet_log "wine desktop $size scoped to Battle.net.exe (WowClassic stays native)"
}

write_client_config() {
  local cfg="$PREFIX/pfx/drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config"
  mkdir -p "$(dirname "$cfg")"
  python3 - "$cfg" "$WOW_UID" <<'PY'
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
wow_uid = sys.argv[2]
data = {}
if path.exists():
    try:
        data = json.loads(path.read_text() or "{}")
    except json.JSONDecodeError:
        data = {}

client = data.setdefault("Client", {})
# CEF on a null D3D pixmap: this is the Blizzard setting, not a Chrome flag.
client["HardwareAcceleration"] = "false"
client["AutoStartMinimized"] = "false"
# "2" = exit Battle.net completely on game launch. This is what frees the
# launcher's ~1.2 GiB for WowClassic, and it also removes the resident
# Battle.net.exe/agent.exe that takes running games down when it crashes.
client["GameLaunchWindowBehavior"] = "2"
client["RestoreWindowOnGameEnd"] = "false"
client.setdefault("Sound", {})["Enabled"] = "false"
client.setdefault("Streaming", {})["StreamingEnabled"] = "false"
client.setdefault("GameSearch", {})["BackgroundSearch"] = "true"
client.setdefault("Install", {})["DownloadLimitNextPatchInBps"] = "0"

# Play logged "-launcherlogin -initialgamemode=bccfresh -uid ..." with no
# -windowed, and a fullscreen game on this virtual desktop never mapped.
game = data.setdefault("Games", {}).setdefault(wow_uid, {})
game["ServerUid"] = wow_uid
game["AdditionalLaunchArguments"] = "-windowed"

data.setdefault("User", {}).setdefault("Client", {})["MinimizedOnStartup"] = "false"
path.write_text(json.dumps(data, indent=4) + "\n")
PY
  bnet_log "wrote $cfg GameLaunchWindowBehavior=2 ${WOW_UID}.AdditionalLaunchArguments=-windowed"
}

# WoW owns Config.wtf. Writing the whole file from here strips the keys the
# game cannot start without — textLocale above all — and WoW then throws
# "assertion failure exception" on startup with no window, no Logs and no
# Errors, which looks exactly like a failed Play. Merge into the game's own
# file, and never invent one: WoW writes a complete, valid config on its
# first run, and hwDetect fills in what this machine can actually do.
write_wow_classic_config() {
  local wtf="$WOW_CLASSIC_DIR/WTF"
  local cfg="$wtf/Config.wtf"
  [[ -d $WOW_CLASSIC_DIR ]] || return 0
  mkdir -p "$wtf"
  if [[ -f $cfg ]] && ! grep -q '^SET textLocale' "$cfg"; then
    rm -f "$cfg"
    bnet_log "removed a Config.wtf with no textLocale — WoW will rebuild it"
  fi
  if [[ ! -f $cfg ]]; then
    bnet_log "no Config.wtf yet — leaving it to WoW's first run"
    return 0
  fi
  python3 - "$cfg" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
# Windowed so the game is never a fullscreen surface fighting the compositor,
# and modest quality because DXVK here is on a 2 GiB advertised heap.
# hwDetect is deliberately absent: the game should keep detecting.
want = {
    "gxApi": "D3D11",
    "gxWindow": "1",
    "gxMaximize": "0",
    "gxFullscreen": "0",
    "gxResolution": "1280x800",
    "gxWindowedResolution": "1280x800",
    "vsync": "0",
    "graphicsQuality": "1",
    "MSAAQuality": "0",
    "particleDensity": "0.10",
    "SSAO": "0",
    "sunShafts": "0",
}

lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
seen = set()
out = []
for line in lines:
    m = re.match(r'^SET\s+(\S+)\s+"(.*)"\s*$', line)
    if m and m.group(1) in want:
        key = m.group(1)
        seen.add(key)
        out.append(f'SET {key} "{want[key]}"')
    else:
        out.append(line)
for key, value in want.items():
    if key not in seen:
        out.append(f'SET {key} "{value}"')
path.write_text("\n".join(out) + "\n", encoding="utf-8")
PY
  bnet_log "merged windowed D3D11 1280x800 into $cfg"
}

# A real file in the shared home, not a quoted FEXBash -c program. Loops and
# `local` silently died inside that string; here they behave normally.
# hold=1 keeps the VM up after the app exits, because Battle.net exits itself
# on Play while WowClassic is still holding the prefix open.
write_guest_script() {
  local name=$1 exe=$2 hold=$3
  shift 3
  local script="$GUEST_DIR/run-$name.sh" a
  {
    echo '#!/bin/bash'
    echo '# Generated by teonix-battlenet. Runs inside the muvm + FEX guest.'
    echo 'set -u'
    guest_env_block
    compat_exports "$exe"
    printf 'PROTON=%q\n' "$PROTON_DIR/proton"
    printf 'WINESERVER=%q\n' "$WINESERVER"
    printf 'EXE=%q\n' "$exe"
    printf 'WOW=%q\n' "$WOW_CLASSIC_EXE"
    printf 'WOW_DIR=%q\n' "$WOW_CLASSIC_DIR"
    printf 'WOW_UID=%q\n' "$WOW_UID"
    printf 'EXE_DIR=%q\n' "$(dirname "$exe")"
    printf 'RESCUE=%q\n' "$RETRY_FLAG"
    printf 'LOG=%q\n' "$BNET_LOG"
    printf 'WINE_PREFIX=%q\n' "$PREFIX/pfx"
    printf 'ARGS=('
    for a in "$@"; do printf ' %q' "$a"; done
    printf ' )\n'
    if [[ $hold == 1 ]]; then
      cat <<'EOS'

# One-shot, best-effort rescue, armed by the host only when Play produced no
# window. It asks Battle.net rather than the game: running WowClassic.exe
# directly throws "assertion failure exception" on repeat and never maps a
# window, even with the launcher up and the account signed in, because the
# game needs the launch token only Play hands it.
#
# Measured: --exec="launch <uid>" against a launcher still sitting on its
# login/security-checkpoint window does nothing. Treat this as a free extra
# attempt, not a fix — the notification tells the user to press Play.
if [[ -f $WOW ]]; then
  (
    tries=0
    while [[ $tries -lt 900 ]]; do
      if [[ -f $RESCUE ]]; then
        rm -f "$RESCUE"
        echo "teonix: rescue — asking Battle.net to launch $WOW_UID" >>"$LOG"
        cd "$EXE_DIR" || exit 1
        "$PROTON" run "$EXE" --exec="launch $WOW_UID" >>"$LOG" 2>&1
        break
      fi
      tries=$((tries + 1))
      sleep 2
    done
  ) &
fi

# Builtins only. The FEX guest's PATH starts with our own guest-bin and the
# x86 rootfs, so pgrep/tr are not something to bet the launch on.
proc_running() {
  local f arg
  for f in /proc/[0-9]*/cmdline; do
    [[ -r $f ]] || continue
    # NUL-delimited read: $(<cmdline) warns "ignored null byte" per process,
    # which floods the log every poll.
    while IFS= read -rd '' arg; do
      case $arg in
        *"$1"*) return 0 ;;
      esac
    done <"$f" 2>/dev/null
  done
  return 1
}

"$PROTON" waitforexitandrun "$EXE" "${ARGS[@]}" || true

# Battle.net has exited — on Play that is deliberate
# (GameLaunchWindowBehavior=2) and WowClassic is still starting. Returning
# here would tear the VM down and take the game with it.
seen_game=0
idle=0
while :; do
  if proc_running WowClassic.exe; then
    seen_game=1
    idle=0
  elif proc_running Battle.net.exe; then
    idle=0
  else
    idle=$((idle + 1))
  fi
  # Game has been and gone: drop the guest promptly.
  [[ $seen_game -eq 1 && $idle -ge 5 ]] && break
  # Game never appeared: hold ~90s so the host's rescue can still land, but
  # do not let a lingering agent.exe own the guest forever.
  [[ $idle -ge 30 ]] && break
  sleep 3
done

# wineserver needs WINEPREFIX itself: Proton only sets it for its children.
export WINEPREFIX="$WINE_PREFIX"
"$WINESERVER" -k >/dev/null 2>&1 || true
EOS
    else
      cat <<'EOS'

# Games resolve their data relative to the exe's directory, so start there.
cd "$EXE_DIR" || exit 1
exec "$PROTON" waitforexitandrun "$EXE" "${ARGS[@]}"
EOS
    fi
  } >"$script"
  chmod +x "$script"
  printf '%s' "$script"
}

guest_running() { teonix_muvm_pid >/dev/null 2>&1; }

count_launches() {
  local n
  n=$(set +o pipefail; grep -h 'Launched .*WowClassic.exe' "$BNET_USER_LOGS"/battle.net-*.log 2>/dev/null | wc -l)
  n=${n// /}
  printf '%s' "${n:-0}"
}

count_logins() {
  local n
  n=$(set +o pipefail; grep -h 'Logged into Battle.net successfully' "$BNET_USER_LOGS"/battle.net-*.log 2>/dev/null | wc -l)
  n=${n// /}
  printf '%s' "${n:-0}"
}

# Address of a real window. The 100x13 ghost HWND (class steam_app_battlenet,
# empty title) is never a target: sizing it covers the whole screen.
hypr_window() {
  hyprctl clients -j 2>/dev/null | python3 -c '
import json, sys

mode = sys.argv[1]
try:
    clients = json.load(sys.stdin)
except Exception:
    raise SystemExit

best = None
for c in clients:
    title = c.get("title") or ""
    cls = c.get("class") or ""
    size = c.get("size") or [0, 0]
    if len(size) < 2 or size[0] < 200 or size[1] < 200:
        continue
    low = (title + " " + cls).lower()
    is_wow = "world of warcraft" in low or "wowclassic" in low
    is_bnet = "battle.net" in low or "steam_app_battlenet" in cls.lower()
    if mode == "wow" and not is_wow:
        continue
    if mode == "any" and not (is_wow or is_bnet):
        continue
    if is_wow or best is None:
        best = c.get("address")
if best:
    print(best)
' "$1" 2>/dev/null || true
}

hypr_place() {
  local addr=$1
  hyprctl eval "hl.dispatch(hl.dsp.focus({ window = \"address:${addr}\" }))" >/dev/null 2>&1 || true
  hyprctl eval 'hl.dispatch(hl.dsp.window.float({ action = "on" }))' >/dev/null 2>&1 || true
  hyprctl eval 'hl.dispatch(hl.dsp.window.center())' >/dev/null 2>&1 || true
}

# Place each new launcher/game window once. Re-centering on every poll would
# fight the user mid-session.
raise_game_windows() {
  (
    set +e
    seen=""
    n=0
    saw_guest=0
    while ((n < 600)); do
      n=$((n + 1))
      sleep 2
      # Started just before muvm, so tolerate a slow guest before giving up.
      if guest_running; then
        saw_guest=1
      elif ((saw_guest == 1)) || ((n > 15)); then
        break
      fi
      addr=$(hypr_window any)
      [[ -z $addr ]] && continue
      case " $seen " in
        *" $addr "*) continue ;;
      esac
      seen="$seen $addr"
      hypr_place "$addr"
      bnet_log "placed window $addr"
    done
  ) >>"$BNET_LOG" 2>&1 &
}

diagnose_failed_play() {
  local latest
  latest=$(set +o pipefail; ls -t "$BNET_USER_LOGS"/battle.net-*.log 2>/dev/null | head -1)
  {
    echo "--- Play produced no window. Client log tail: ---"
    [[ -n $latest ]] && tail -12 "$latest" 2>/dev/null
    echo "--- host memory ---"
    awk '/MemAvailable:|SwapFree:/ { print "  " $1 " " int($2 / 1024) " MiB" }' /proc/meminfo
    echo "--- WoW logs written? ---"
    ls -t "$WOW_CLASSIC_DIR/Logs" 2>/dev/null | head -3 || echo "  none"
    echo "---"
  } >>"$BNET_LOG" 2>&1
  if [[ -n $latest ]] && tail -12 "$latest" 2>/dev/null | grep -q 'Render process was terminated'; then
    bnet_result launcher-crash "CEF renderer died right after Play"
  else
    bnet_result no-window "game never mapped a window"
  fi
}

# Watch the launcher's own log for Play, then prove a window appeared. One
# bounded rescue inside the same guest — never a second VM, because
# -launcherlogin with no launcher hangs forever with no window.
verify_play() {
  local pre
  pre=$(count_launches)
  rm -f "$RETRY_FLAG"
  (
    set +e
    seen=$pre
    rescued=0
    waited=0
    saw_guest=0
    while ((waited < 3600)); do
      sleep 3
      waited=$((waited + 3))
      if guest_running; then
        saw_guest=1
      elif ((saw_guest == 1)) || ((waited > 30)); then
        break
      fi
      now=$(count_launches)
      ((now <= seen)) && continue
      seen=$now
      bnet_log "Play pressed — waiting for the WoW window"
      win=""
      probe=0
      while ((probe < 20)); do
        probe=$((probe + 1))
        sleep 3
        guest_running || break
        win=$(hypr_window wow)
        [[ -n $win ]] && break
      done
      if [[ -n $win ]]; then
        hypr_place "$win"
        bnet_result ok "WoW window $win"
        bnet_notify "WoW Classic" "Game window is up."
        continue
      fi
      diagnose_failed_play
      if ((rescued == 0)); then
        rescued=1
        : >"$RETRY_FLAG"
        bnet_log "rescue: asked the guest for a launcher-side launch"
        bnet_notify "WoW Classic" "Play did not open a window. Retrying once — if nothing appears, press Play again. Details: teonix-battlenet doctor"
      fi
    done
  ) >>"$BNET_LOG" 2>&1 &
}

run_in_guest() {
  local exe=$1
  shift
  local mem vram script hold=0 name=setup
  mem=$(mem_mib)
  vram=$(vram_mib "$mem")
  install_guest_xdg_open
  write_dxvk_conf
  write_wine_registry

  if [[ $exe == *Battle.net.exe ]]; then
    name=battlenet
    hold=1
  fi
  script=$(write_guest_script "$name" "$exe" "$hold" "$@")
  bnet_log "muvm mem=${mem}M vram=${vram}M script=$script exe=$exe"

  if [[ $hold == 1 && -f $WOW_CLASSIC_EXE ]]; then
    echo "Starting Battle.net (guest ceiling ${mem} MiB)."
    echo "Log in and press Play: WoW opens windowed and the launcher closes itself."
    ram_report
    verify_play
    if [[ ${TEONIX_AUTOPLAY:-0} == 1 ]]; then
      autoplay_when_logged_in
    fi
  else
    echo "Starting Battle.net (guest ceiling ${mem} MiB). Log: $BNET_LOG"
    ram_report
  fi
  raise_game_windows
  muvm --mem="$mem" --vram="$vram" -e DISPLAY \
    -- FEXBash -c "exec bash $(printf '%q' "$script")" >>"$BNET_LOG" 2>&1
}

# Wait for the session, then ask the launcher to start the game, which is the
# same path the Play button takes.
autoplay_when_logged_in() {
  local pre
  pre=$(count_logins)
  (
    set +e
    waited=0
    saw_guest=0
    while ((waited < 900)); do
      sleep 3
      waited=$((waited + 3))
      if guest_running; then
        saw_guest=1
      elif ((saw_guest == 1)) || ((waited > 30)); then
        break
      fi
      if (($(count_logins) > pre)); then
        sleep 4
        : >"$RETRY_FLAG"
        bnet_log "autoplay: asked Battle.net to launch $WOW_UID"
        break
      fi
    done
  ) >>"$BNET_LOG" 2>&1 &
}

# "Skip the click", not "skip the launcher". WowClassic.exe on its own throws
# assertion failure exceptions forever and never maps a window, even with the
# launcher up and the account signed in — the game will not start without the
# launch token Play gives it. So boot the launcher and, once the session is
# up, ask it to launch the game. That request is best-effort: if the launcher
# is still on a login or security-checkpoint window it is ignored, and Play
# is still the reliable route.
run_wow_direct() {
  local launcher
  launcher=$(find_launcher) || {
    echo "teonix: Battle.net is not installed yet — run teonix-battlenet first." >&2
    return 1
  }
  [[ -f $WOW_CLASSIC_EXE ]] || {
    echo "teonix: WoW Classic is not installed yet — open Battle.net and install it." >&2
    return 1
  }
  echo "WoW cannot boot without Battle.net — starting the launcher and asking it for the game."
  echo "If the launcher stops at login or a security checkpoint, finish that and press Play."
  TEONIX_AUTOPLAY=1
  write_client_config
  write_wow_classic_config
  run_in_guest "$launcher" "${CEF_ARGS[@]}"
}

doctor() {
  local launcher cfg
  echo "teonix Battle.net doctor"
  echo
  echo "host"
  printf '  page size    %s\n' "$(getconf PAGESIZE)"
  printf '  muvm         %s\n' "$([[ -x /usr/bin/muvm ]] && echo present || echo MISSING)"
  printf '  FEXBash      %s\n' "$(command -v FEXBash >/dev/null && echo present || echo MISSING)"
  awk '/MemTotal:|MemAvailable:|SwapFree:/ { printf "  %-12s %d MiB\n", $1, int($2 / 1024) }' /proc/meminfo
  printf '  guest ceiling %s MiB (vram %s MiB)\n' "$(mem_mib)" "$(vram_mib "$(mem_mib)")"
  echo
  echo "proton"
  printf '  %s %s\n' "$PROTON_TAG" "$([[ -x $PROTON_DIR/proton ]] && echo ok || echo MISSING)"
  printf '  wine arch    %s\n' "$(file -b "$PROTON_DIR/files/bin/wine" 2>/dev/null | cut -d, -f1 || echo unknown)"
  echo
  echo "prefix"
  launcher=$(find_launcher || true)
  printf '  Battle.net   %s\n' "${launcher:-MISSING}"
  printf '  WowClassic   %s\n' "$([[ -f $WOW_CLASSIC_EXE ]] && echo "$WOW_CLASSIC_EXE" || echo 'not installed')"
  printf '  wine desktop %s (Battle.net.exe only)\n' "$(screen_desktop_size)"
  if [[ -f $WOW_CLASSIC_DIR/WTF/Config.wtf ]]; then
    if grep -q '^SET textLocale' "$WOW_CLASSIC_DIR/WTF/Config.wtf"; then
      printf '  Config.wtf   ok (textLocale present)\n'
    else
      printf '  Config.wtf   BAD — no textLocale, WoW will assert on startup\n'
    fi
  else
    printf '  Config.wtf   absent (WoW writes it on first run)\n'
  fi
  echo
  echo "managed launcher settings"
  cfg="$PREFIX/pfx/drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config"
  if [[ -f $cfg ]]; then
    python3 - "$cfg" "$WOW_UID" <<'PY'
import json
import sys
from pathlib import Path

try:
    data = json.loads(Path(sys.argv[1]).read_text() or "{}")
except Exception as exc:
    print(f"  unreadable: {exc}")
    raise SystemExit

client = data.get("Client", {})
game = data.get("Games", {}).get(sys.argv[2], {})
rows = [
    ("GameLaunchWindowBehavior", client.get("GameLaunchWindowBehavior"), "2"),
    ("HardwareAcceleration", client.get("HardwareAcceleration"), "false"),
    ("RestoreWindowOnGameEnd", client.get("RestoreWindowOnGameEnd"), "false"),
    ("Sound.Enabled", client.get("Sound", {}).get("Enabled"), "false"),
    ("Streaming.StreamingEnabled", client.get("Streaming", {}).get("StreamingEnabled"), "false"),
    ("AdditionalLaunchArguments", game.get("AdditionalLaunchArguments"), "-windowed"),
]
for name, actual, want in rows:
    mark = "ok " if actual == want else "BAD"
    print(f"  {mark} {name} = {actual!r} (want {want!r})")
PY
  else
    echo "  no Battle.net.config yet"
  fi
  echo
  echo "guest"
  printf '  running      %s\n' "$(guest_running && echo yes || echo no)"
  echo
  echo "last verdicts"
  grep 'RESULT:' "$BNET_LOG" 2>/dev/null | tail -5 | sed 's/^/  /' || echo "  none yet"
}
