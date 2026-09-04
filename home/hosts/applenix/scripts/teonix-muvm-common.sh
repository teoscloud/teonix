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

# muvm renames itself to "libkrun VM" once the VM is up, so `pgrep -x muvm`
# reports no guest while one is plainly running. Matching the command line
# instead makes any shell that merely mentions muvm look like a guest, which
# is how a relaunch ended up refusing itself. The exe link survives the
# rename and cannot be spoofed by an argument.
teonix_muvm_pid() {
  local dir exe
  for dir in /proc/[0-9]*; do
    exe=$(readlink "$dir/exe" 2>/dev/null) || continue
    case $exe in
      */muvm) printf '%s' "${dir#/proc/}"; return 0 ;;
    esac
  done
  return 1
}

teonix_muvm_busy() {
  teonix_muvm_pid >/dev/null && return 0
  pgrep -f 'steamwebhelper' >/dev/null 2>&1 \
    || pgrep -f '/usr/bin/python3 /usr/bin/steam' >/dev/null 2>&1
}

# Advisory only. muvm hands the guest memory on demand and returns free pages
# to the host, and there is an 8 GiB swapfile behind it, so a low MemAvailable
# means "expect swap", not "cannot start". Never block a launch.
# Optional first arg: the comfortable MemAvailable MiB for this guest.
teonix_ram_gate() {
  local need=${1:-1536}
  local avail
  avail=$(awk '/MemAvailable:/ { print int($2 / 1024) }' /proc/meminfo)
  if ((avail < need)); then
    echo "teonix: ${avail} MiB free, comfortable is ~${need} MiB — starting anyway, the host will swap."
    ps -eo rss,comm --sort=-rss --no-headers 2>/dev/null \
      | awk 'NR<=3 { printf "teonix:   %-24s %d MiB\n", $2, $1 / 1024 }'
  fi
  return 0
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
