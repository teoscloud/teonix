#!/usr/bin/env bash
# core-fence: keep the compositor's reserved CPUs for the compositor.
#
# hosts/mainframe/compositor-core.nix pins wayland-wm@hyprland.desktop.service to
# an isolated core. Affinity is inherited, so everything Hyprland forks starts
# pinned there too. Apps launched through `uwsm app --` are moved into a scope
# whose cpuset overrides that; what never leaves the compositor's own cgroup —
# Xwayland, wl-copy's clipboard server, anything exec'd bare — would sit on the
# render thread's core for the life of the session (Xwayland presenting every
# Steam/WoW frame from there was the 2026-09-22 stutter).
#
# Every 5 s: for each thread in the compositor's cgroup that is not a Hyprland
# thread and whose mask touches an isolated CPU, set its affinity to the
# housekeeping CPUs. Exits at once on hosts without isolated CPUs. Runs under
# `uwsm app -s b` from hyprland.lua, so it is itself fenced by the background
# slice's cpuset. Logs only when it moves something (journal of the scope).
set -u

isolated=$(cat /sys/devices/system/cpu/isolated 2>/dev/null || true)
[ -n "$isolated" ] || exit 0
present=$(cat /sys/devices/system/cpu/present)

# "0-3,8" -> one number per line
expand() {
  local part
  IFS=, read -ra parts <<<"$1"
  for part in "${parts[@]}"; do
    if [[ $part == *-* ]]; then seq "${part%-*}" "${part#*-}"; else echo "$part"; fi
  done
}
declare -A iso=()
for c in $(expand "$isolated"); do iso[$c]=1; done
housekeeping=$(for c in $(expand "$present"); do [ -n "${iso[$c]:-}" ] || echo "$c"; done | paste -sd,)
[ -n "$housekeeping" ] || exit 0

touches_isolated() { # $1 = Cpus_allowed_list
  local c
  for c in $(expand "$1"); do [ -n "${iso[$c]:-}" ] && return 0; done
  return 1
}

# Hyprland's PID: from the instance lock file, else the process list.
hypr_pid() {
  local sig=${HYPRLAND_INSTANCE_SIGNATURE:-} lock
  if [ -n "$sig" ]; then
    lock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$sig/hyprland.lock"
    [ -r "$lock" ] && head -1 "$lock" && return
  fi
  pgrep -f '(^|/)Hyprland( |$)' | head -1
}

log() { printf 'core-fence: %s\n' "$*" >&2; }
log "isolated $isolated, housekeeping $housekeeping"

while :; do
  pid=$(hypr_pid)
  if [ -n "$pid" ] && [ -r "/proc/$pid/cgroup" ]; then
    cg=$(awk -F: '$1==0 {print $3}' "/proc/$pid/cgroup")
    threads="/sys/fs/cgroup$cg/cgroup.threads"
    if [ -r "$threads" ]; then
      while read -r tid; do
        [ -r "/proc/$tid/status" ] || continue
        tgid=$(awk '/^Tgid:/ {print $2}' "/proc/$tid/status")
        [ "$tgid" = "$pid" ] && continue
        mask=$(awk '/^Cpus_allowed_list:/ {print $2}' "/proc/$tid/status")
        [ -n "$mask" ] && touches_isolated "$mask" || continue
        if taskset -pc "$housekeeping" "$tid" >/dev/null 2>&1; then
          log "moved $(cat "/proc/$tid/comm" 2>/dev/null) tid $tid (pid $tgid) off $mask"
        fi
      done <"$threads"
    fi
  fi
  sleep 5
done
