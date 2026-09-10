#!/usr/bin/env bash
# Display safety for a GPU that cannot drive every attached panel at full rate.
#
# Nothing here names a connector, a DRM card index or a specific monitor. Outputs
# are discovered from `hyprctl monitors` and verified against sysfs, so any panel
# works in any DP/HDMI port. Selectors may be a connector name or a `desc:` prefix.
#
# Two limits are read from /etc/teonix/display-bandwidth.conf, written by
# hosts/mainframe/gpu-quirks-polaris.nix. If that file is absent (other hosts, or
# after a GPU upgrade that drops the quirks) no limits are applied at all.
#
#   TEONIX_MAX_PIXEL_RATE_MPS     hard per-output BAN: any mode whose w*h*refresh
#                                 exceeds this many megapixels/s is never selected.
#                                 On the RX 580 this outlaws 5120x1440@120 (~885)
#                                 while allowing 5120x1440@60 and 2560x1440@120
#                                 (both ~442) with extra outputs attached.
#   TEONIX_MAX_REFRESH_MULTI_OUTPUT  refresh cap for SECONDARY outputs.
#
# Modes:
#   safe                    reduce to one output at a mode that actually commits
#   ultrawide               primary at its largest-area allowed mode (5120x1440@60
#                           on the G9), every other output on
#   highrefresh             primary at its highest-refresh allowed mode
#                           (2560x1440@120 on the G9), every other output on
#   verify-or-revert SEL    fall back to `safe` if SEL did not really light up
#   watchdog                loop: if no output is enabled at all, recover
#   save-and-deescalate     remember the layout then go safe (pre-suspend)
#   restore                 re-apply the remembered layout (post-resume)
set -uo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/teonix-display"
SAVED="$STATE_DIR/saved-layout.json"
BW_CONF=/etc/teonix/display-bandwidth.conf

# The environment overrides the config file, for one-off testing. Capture it
# BEFORE sourcing the file, which sets the same variable names.
_env_cap="${TEONIX_MAX_REFRESH_MULTI_OUTPUT:-}"
_env_px="${TEONIX_MAX_PIXEL_RATE_MPS:-}"
# shellcheck source=/dev/null
[ -r "$BW_CONF" ] && . "$BW_CONF"
CAP="${_env_cap:-${TEONIX_MAX_REFRESH_MULTI_OUTPUT:-}}"
PXRATE="${_env_px:-${TEONIX_MAX_PIXEL_RATE_MPS:-}}"

log() { printf 'display-safe: %s\n' "$*" >&2; }

have_hypr() { hyprctl monitors -j >/dev/null 2>&1; }
monitors_json() { hyprctl monitors -j 2>/dev/null; }

# ---------------------------------------------------------------- sysfs truth

# Hyprland reports a mode even when the atomic commit failed, so sysfs is the only
# reliable answer. The card index is globbed, never assumed.
sysfs_enabled() {
  local name="$1" f
  for f in /sys/class/drm/card*-"$name"/enabled; do
    [ -r "$f" ] || continue
    cat "$f"
    return 0
  done
  printf 'unknown\n'
}

any_output_enabled() {
  local f
  for f in /sys/class/drm/card*-*/enabled; do
    [ -r "$f" ] || continue
    [ "$(cat "$f")" = "enabled" ] && return 0
  done
  return 1
}

# ---------------------------------------------------------------- discovery

# `python3 - <<HEREDOC` takes its *program* from stdin, so monitor data cannot be
# piped in as well. Snapshot to a file and pass the path as an argument instead.
#
# `monitors all` is deliberate: a disabled output disappears from plain `monitors`,
# which would make it impossible to ever switch back on.
snapshot() {
  local f
  f="$(mktemp "${TMPDIR:-/tmp}/teonix-monitors.XXXXXX")" || return 1
  if ! hyprctl monitors all -j >"$f" 2>/dev/null || [ ! -s "$f" ]; then
    rm -f "$f"
    return 1
  fi
  printf '%s' "$f"
}

# Resolve a connector name or `desc:PREFIX` selector to a live connector name.
resolve_name() {
  local sel="$1" f
  case "$sel" in
    desc:*)
      f="$(snapshot)" || return 1
      python3 - "$f" "${sel#desc:}" <<'PY'
import json, sys
monitors = json.load(open(sys.argv[1]))
prefix = sys.argv[2]
for m in monitors:
    if m.get("description", "").startswith(prefix):
        print(m["name"])
        break
PY
      rm -f "$f"
      ;;
    *) printf '%s\n' "$sel" ;;
  esac
}

all_names() {
  local f
  f="$(snapshot)" || return 1
  python3 - "$f" <<'PY'
import json, sys
for m in json.load(open(sys.argv[1])):
    print(m["name"])
PY
  rm -f "$f"
}

# The primary is whichever panel can show the most pixels, taken from its own
# availableModes rather than its current (possibly failed) mode. No name preference.
pick_primary() {
  local f
  f="$(snapshot)" || return 1
  python3 - "$f" <<'PY'
import json, re, sys
best = None
for m in json.load(open(sys.argv[1])):
    area = 0
    for mode in m.get("availableModes", []):
        g = re.match(r"(\d+)x(\d+)@", mode)
        if g:
            area = max(area, int(g.group(1)) * int(g.group(2)))
    if best is None or area > best[0]:
        best = (area, m["name"])
print(best[1] if best else "")
PY
  rm -f "$f"
}

# Best allowed mode for one output: best_mode NAME [REFRESH_CAP] [KEY]
#   KEY "area"    (default) prefer pixel count, then refresh  -> ultrawide/safe
#   KEY "refresh" prefer refresh, then pixel count            -> highrefresh
# Modes above the pixel-rate budget (PXRATE, Mpx/s) are never considered: that is
# the hard ban on modes this GPU cannot survive, monitor- and port-agnostic.
best_mode() {
  local f
  f="$(snapshot)" || return 1
  python3 - "$f" "$1" "${2:-}" "${3:-area}" "$PXRATE" <<'PY'
import json, re, sys
monitors = json.load(open(sys.argv[1]))
name = sys.argv[2]
cap = float(sys.argv[3]) if sys.argv[3] else None
by_refresh = sys.argv[4] == "refresh"
pxrate = float(sys.argv[5]) if sys.argv[5] else None
for m in monitors:
    if m["name"] != name:
        continue
    best = None
    for mode in m.get("availableModes", []):
        g = re.match(r"(\d+)x(\d+)@([\d.]+)", mode)
        if not g:
            continue
        w, h, r = int(g.group(1)), int(g.group(2)), float(g.group(3))
        if cap is not None and r > cap + 0.5:
            continue
        if pxrate is not None and w * h * r / 1e6 > pxrate + 1:
            continue
        key = (r, w * h) if by_refresh else (w * h, r)
        if best is None or key > best[0]:
            best = (key, "%dx%d@%g" % (w, h, r))
    print(best[1] if best else "preferred")
    break
PY
  rm -f "$f"
}

# Mode actually in effect on one output, as WxH@R.
current_mode() {
  local f
  f="$(snapshot)" || return 1
  python3 - "$f" "$1" <<'PY'
import json, sys
for m in json.load(open(sys.argv[1])):
    if m["name"] == sys.argv[2]:
        print("%dx%d@%g" % (m["width"], m["height"], round(m["refreshRate"])))
        break
PY
  rm -f "$f"
}

# Compare WxH@R strings, tolerating the usual 59.98-vs-60 rounding.
modes_match() {
  python3 - "$1" "$2" <<'PY'
import re, sys
def parse(s):
    g = re.match(r"(\d+)x(\d+)@([\d.]+)", s or "")
    return (int(g.group(1)), int(g.group(2)), float(g.group(3))) if g else None
a, b = parse(sys.argv[1]), parse(sys.argv[2])
ok = a is not None and b is not None and a[:2] == b[:2] and abs(a[2] - b[2]) <= 1.5
sys.exit(0 if ok else 1)
PY
}

# ---------------------------------------------------------------- modes

cmd_safe() {
  have_hypr || { log "hyprland not reachable"; return 1; }

  local primary mode n
  primary="$(pick_primary)"
  [ -n "$primary" ] || { log "no outputs reported"; return 1; }

  mode="$(best_mode "$primary" "$CAP")"
  if [ -n "$CAP" ]; then
    log "safe mode: $primary at $mode (cap ${CAP}Hz), other outputs off"
  else
    log "safe mode: $primary at $mode (no cap configured), other outputs off"
  fi

  # Free the bandwidth before asking for the primary mode, or the commit fails.
  while read -r n; do
    [ -z "$n" ] && continue
    [ "$n" = "$primary" ] && continue
    hyprctl keyword monitor "$n,disable" >/dev/null 2>&1
  done < <(all_names)
  sleep 1

  hyprctl keyword monitor "$primary,$mode,0x0,1" >/dev/null 2>&1
  sleep 1

  if [ "$(sysfs_enabled "$primary")" = "enabled" ]; then
    log "ok: $primary is enabled"
    return 0
  fi

  log "WARNING: $primary did not commit at $mode; retrying at preferred"
  hyprctl keyword monitor "$primary,preferred,0x0,1" >/dev/null 2>&1
  sleep 1
  if [ "$(sysfs_enabled "$primary")" = "enabled" ]; then
    log "ok: $primary is enabled at preferred"
    return 0
  fi

  log "ERROR: could not enable $primary; asking hyprland to reload its config"
  hyprctl reload >/dev/null 2>&1
  return 1
}

# Secondary placement: every other output sits ABOVE the primary, bottom edges
# flush with the primary's top, packed right-to-left starting at the primary's
# right edge. Rightmost-first order is a descending sort of the monitor
# descriptions — on this desk that puts the Samsung S27E590 in the top-right
# corner of the G9 and the ASUS VG245 to its left, in every primary mode.
# Emits one "name,WxH@R,XxY" line per secondary (or auto-up when a mode or the
# primary's geometry cannot be parsed).
plan_secondaries() {
  local f
  f="$(snapshot)" || return 1
  python3 - "$f" "$1" "$2" "$CAP" "$PXRATE" <<'PY'
import json, re, sys
monitors = json.load(open(sys.argv[1]))
primary, pmode = sys.argv[2], sys.argv[3]
cap = float(sys.argv[4]) if sys.argv[4] else None
px = float(sys.argv[5]) if sys.argv[5] else None

g = re.match(r"(\d+)x(\d+)@", pmode)
xright = int(g.group(1)) if g else None

def best(m):
    found = None
    for mode in m.get("availableModes", []):
        mm = re.match(r"(\d+)x(\d+)@([\d.]+)", mode)
        if not mm:
            continue
        w, h, r = int(mm.group(1)), int(mm.group(2)), float(mm.group(3))
        if cap is not None and r > cap + 0.5:
            continue
        if px is not None and w * h * r / 1e6 > px + 1:
            continue
        key = (w * h, r)
        if found is None or key > found[0]:
            found = (key, (w, h, r))
    return found[1] if found else None

secondaries = [m for m in monitors if m["name"] != primary]
secondaries.sort(key=lambda m: m.get("description", ""), reverse=True)
for m in secondaries:
    b = best(m)
    if b is None or xright is None:
        print("%s,preferred,auto-up" % m["name"])
        continue
    w, h, r = b
    x = xright - w
    print("%s,%dx%d@%g,%dx%d" % (m["name"], w, h, r, x, -h))
    xright = x
PY
  rm -f "$f"
}

# Primary at its best allowed mode (by KEY) at 0x0, secondaries re-anchored above
# it. Both live layouts go through here; the pixel-rate ban in best_mode means
# nothing this GPU cannot survive is ever requested.
apply_multi() {
  local key="$1" label="$2"
  have_hypr || { log "hyprland not reachable"; return 1; }

  local primary mode line
  primary="$(pick_primary)"
  [ -n "$primary" ] || { log "no outputs reported"; return 1; }

  # No refresh cap on the primary: the pixel-rate budget is the real limit.
  mode="$(best_mode "$primary" "" "$key")"
  log "$label: $primary at $mode plus every other output above it"
  hyprctl keyword monitor "$primary,$mode,0x0,1,bitdepth,8" >/dev/null 2>&1

  while IFS= read -r line; do
    [ -z "$line" ] && continue
    hyprctl keyword monitor "$line,1,bitdepth,8" >/dev/null 2>&1
  done < <(plan_secondaries "$primary" "$mode")

  cmd_verify_or_revert "$primary" "$mode"
}

# Largest picture: most pixels first (5120x1440@60 on the G9).
cmd_ultrawide()   { apply_multi area "ultrawide mode"; }
# Fastest picture: highest refresh first (2560x1440@120 on the G9).
cmd_highrefresh() { apply_multi refresh "high-refresh mode"; }

# Two distinct failure modes, which deserve different reactions:
#   - the output is dark        -> genuinely broken, revert to safe mode
#   - the output kept its old mode -> hyprland refused the modeset, nothing is
#     broken, so just say so rather than thrashing the display
cmd_verify_or_revert() {
  local sel="${1:-}" expected="${2:-}" name got
  [ -n "$sel" ] || { log "verify-or-revert needs a selector"; return 2; }

  sleep 1
  name="$(resolve_name "$sel")"
  if [ -z "$name" ]; then
    log "$sel matches no connected output; reverting to safe mode"
    cmd_safe
    return
  fi

  if [ "$(sysfs_enabled "$name")" != "enabled" ]; then
    log "$name ($sel) is not enabled; reverting to safe mode"
    cmd_safe
    return
  fi

  if [ -n "$expected" ]; then
    got="$(current_mode "$name")"
    if ! modes_match "$got" "$expected"; then
      log "$name is alive at $got but refused $expected (bandwidth limit); keeping $got"
      return 0
    fi
  fi

  log "$name ($sel) is enabled${expected:+ at $expected}"
  return 0
}

cmd_watchdog() {
  log "watchdog started"
  while :; do
    sleep 5
    have_hypr || continue
    any_output_enabled && continue

    log "no output is enabled — attempting recovery"
    # A config reload is what actually recovered this state in testing.
    hyprctl reload >/dev/null 2>&1
    sleep 2
    any_output_enabled && { log "recovered via reload"; continue; }

    cmd_safe || log "recovery failed; will retry"
  done
}

cmd_save_and_deescalate() {
  mkdir -p "$STATE_DIR"
  if have_hypr; then
    monitors_json >"$SAVED" 2>/dev/null || rm -f "$SAVED"
  fi
  cmd_safe || true
}

cmd_restore() {
  have_hypr || { log "hyprland not reachable"; return 1; }

  if [ ! -r "$SAVED" ]; then
    log "no saved layout; reloading config"
    hyprctl reload >/dev/null 2>&1
    return 0
  fi

  # Re-apply by description, so a panel that moved ports still gets its layout.
  while read -r rule; do
    [ -z "$rule" ] && continue
    hyprctl keyword monitor "$rule" >/dev/null 2>&1
  done < <(python3 - "$SAVED" <<'PY'
import json, sys
try:
    monitors = json.load(open(sys.argv[1]))
except Exception:
    sys.exit(0)
for m in monitors:
    if m.get("disabled"):
        continue
    w, h = m.get("width", 0), m.get("height", 0)
    if not w or not h:
        continue
    desc = m.get("description", "")
    sel = "desc:" + desc if desc else m["name"]
    print("%s,%dx%d@%.2f,%dx%d,%s" % (
        sel, w, h, m.get("refreshRate", 60.0),
        m.get("x", 0), m.get("y", 0), m.get("scale", 1)))
PY
  )

  sleep 1
  if ! any_output_enabled; then
    log "restore left no output enabled; going safe"
    cmd_safe
  fi
}

case "${1:-}" in
  safe)                cmd_safe ;;
  ultrawide)           cmd_ultrawide ;;
  highrefresh)         cmd_highrefresh ;;
  verify-or-revert)    shift; cmd_verify_or_revert "${1:-}" "${2:-}" ;;
  watchdog)            cmd_watchdog ;;
  save-and-deescalate) cmd_save_and_deescalate ;;
  restore)             cmd_restore ;;
  *)
    printf 'usage: %s {safe|ultrawide|highrefresh|verify-or-revert SEL|watchdog|save-and-deescalate|restore}\n' \
      "$(basename "$0")" >&2
    exit 2
    ;;
esac
