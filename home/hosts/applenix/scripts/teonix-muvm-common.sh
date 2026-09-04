# Shared by teonix-steam / battlenet / wow / wowup. One 4K muvm on this Air.
# shellcheck shell=bash

TEONIX_MUVM_LOCK="${XDG_RUNTIME_DIR:-/tmp}/teonix-muvm.lock"

# Host Fedora only. Nix Qt/Mesa/GL paths abort the FEX guest.
teonix_host_fedora_env() {
  unset QT_PLUGIN_PATH QT_PLUGIN_PATH_1 QML2_IMPORT_PATH QML_IMPORT_PATH
  unset QTWEBENGINEPROCESS_PATH QT_QPA_PLATFORM_PLUGIN_PATH QT_QPA_PLATFORMTHEME
  unset LIBGL_DRIVERS_PATH GBM_BACKENDS_PATH __EGL_VENDOR_LIBRARY_FILENAMES
  unset LD_LIBRARY_PATH
  export PATH="/usr/bin:/usr/sbin${PATH:+:$PATH}"
}

teonix_need_muvm() {
  [[ -x /usr/bin/muvm ]] && command -v FEXBash >/dev/null || {
    echo "teonix: muvm/FEXBash missing — bash ~/teonix/hosts/applenix/fedora.sh steam" >&2
    return 1
  }
}

teonix_muvm_busy() {
  pgrep -x muvm >/dev/null 2>&1 \
    || pgrep -f 'muvm -- FEXBash' >/dev/null 2>&1 \
    || pgrep -f 'steamwebhelper' >/dev/null 2>&1 \
    || pgrep -f '/usr/bin/python3 /usr/bin/steam' >/dev/null 2>&1
}

# Refuse to start a 3–4 GiB guest when the host is already swapping CEF to death.
# Optional first arg: minimum MemAvailable MiB (default 1536).
teonix_ram_gate() {
  local need=${1:-1536}
  local avail
  avail=$(awk '/MemAvailable:/ { print int($2 / 1024) }' /proc/meminfo)
  if ((avail < need)); then
    echo "teonix: only ${avail} MiB free (need ~${need} MiB). Close Brave/YouTube/extra Cursor, then retry." >&2
    echo "teonix: last gray/null Battle.net pixmap was ~570 MiB free." >&2
    return 1
  fi
}

# Caller must keep fd 9 open. Returns 1 if another wrapper holds the lock or a guest is up.
teonix_muvm_lock() {
  local who=${1:-another teonix guest}
  if teonix_muvm_busy; then
    echo "teonix: a muvm guest is already running. teonix-battlenet-kill first — one guest on this Air." >&2
    return 1
  fi
  mkdir -p "$(dirname "$TEONIX_MUVM_LOCK")"
  exec 9>"$TEONIX_MUVM_LOCK"
  if ! flock -n 9; then
    echo "teonix: $who cannot start — another wrapper holds $TEONIX_MUVM_LOCK" >&2
    return 1
  fi
  if teonix_muvm_busy; then
    echo "teonix: a muvm guest is already running. teonix-battlenet-kill first — one guest on this Air." >&2
    return 1
  fi
}
