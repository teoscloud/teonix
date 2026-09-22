#!/usr/bin/env bash
# Display safety for a GPU that cannot drive every attached panel at full rate.
#
# Nothing here names a connector, a DRM card index or a specific monitor. Outputs
# are discovered from `hyprctl monitors` and verified against sysfs, so any panel
# works in any DP/HDMI port. Selectors may be a connector name or a `desc:` prefix.
#
# Two limits are read from /run/teonix/display-bandwidth.conf if it exists and
# /etc/teonix/display-bandwidth.conf otherwise, both written by
# hosts/mainframe/gpu.nix: the /run one per boot for whichever card is fitted, the
# /etc one as a conservative fallback. If neither exists (other hosts) no limits
# are applied at all.
#
#   TEONIX_MAX_PIXEL_RATE_MPS     hard per-output BAN: any mode whose w*h*refresh
#                                 exceeds this many megapixels/s is never selected.
#                                 On the Arc A750 (2000) nothing is banned: the G9
#                                 runs 5120x1440@240 (~1767). Passing 900 in the
#                                 environment (Super+Ctrl+S) admits only the
#                                 single-pipe modes 5120x1440@120 and 2560x1440@240
#                                 (both ~885). On the RX 580 (450) it outlaws
#                                 5120x1440@120 (~885) while allowing 5120x1440@60
#                                 and 2560x1440@120 (~442).
#   TEONIX_MAX_REFRESH_MULTI_OUTPUT  refresh cap for SECONDARY outputs.
#   TEONIX_SECONDARY_REFRESH_CAP  compositor budget for SECONDARY outputs, default
#                                 60: never a bandwidth issue, but every Hz on any
#                                 output is one more render pass per second.
#
# Modes:
#   safe                    reduce to one output at a mode that actually commits
#   ultrawide               primary at its largest-area allowed mode, fastest refresh
#                           (G9: Arc 5120x1440@240, RX 580 5120x1440@60), every other
#                           output on
#   highrefresh             primary at its highest-refresh allowed mode (G9: Arc
#                           5120x1440@240 too, RX 580 2560x1440@120), every other
#                           output on
#   verify-or-revert SEL    fall back to `safe` if SEL did not really light up
#   watchdog                loop: if no output is enabled at all, recover
#   follow                  loop: after every monitoradded event (the G9 toggling
#                           PIP is a DP reconnect with a smaller EDID), re-anchor
#                           the layout as `ultrawide` would (no-op if already
#                           right) and restore scrolling-layout column widths in
#                           pixels (scroll-columns.py). Every 5 quiet seconds,
#                           re-place secondaries that drifted off the primary's
#                           current footprint. Logs to
#                           $XDG_RUNTIME_DIR/teonix-display/follow.log
#   save-and-deescalate     remember the layout then go safe (pre-suspend)
#   restore                 re-apply the remembered layout (post-resume)
set -uo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/teonix-display"
SAVED="$STATE_DIR/saved-layout.json"
# Per-boot profile for the fitted card first, packaged fallback second.
BW_CONFS="/run/teonix/display-bandwidth.conf /etc/teonix/display-bandwidth.conf"

# The environment overrides the config file, for one-off testing. Capture it
# BEFORE sourcing the file, which sets the same variable names.
_env_cap="${TEONIX_MAX_REFRESH_MULTI_OUTPUT:-}"
_env_px="${TEONIX_MAX_PIXEL_RATE_MPS:-}"
for _bw in $BW_CONFS; do
  # shellcheck source=/dev/null
  [ -r "$_bw" ] && { . "$_bw"; break; }
done
CAP="${_env_cap:-${TEONIX_MAX_REFRESH_MULTI_OUTPUT:-}}"
PXRATE="${_env_px:-${TEONIX_MAX_PIXEL_RATE_MPS:-}}"
# Secondaries never run above this, whatever the GPU could afford: every Hz on
# any output is one more full compositor pass per second on Hyprland's single
# render thread (the ASUS VG245 advertises 75; 60 matches hyprland.lua). Not a
# bandwidth limit, a compositor budget. Empty disables it.
SEC_CAP="${TEONIX_SECONDARY_REFRESH_CAP-60}"

log() { printf 'display-safe: %s\n' "$*" >&2; }

have_hypr() { hyprctl monitors -j >/dev/null 2>&1; }
monitors_json() { hyprctl monitors -j 2>/dev/null; }

# Hyprland's Lua config (0.55+) has no `hyprctl keyword`; monitor rules are set
# with `hyprctl eval 'hl.monitor({...})'`, which merges into the existing rule
# for that output and applies it. Same one-line rule strings as before:
#   hypr_monitor 'SEL,MODE,POS[,SCALE[,bitdepth,N]]'   |   hypr_monitor 'SEL,disable'
lua_str() { local s="${1//\\/\\\\}"; s="${s//\"/\\\"}"; printf '"%s"' "$s"; }
hypr_monitor() {
  local -a f
  IFS=, read -ra f <<< "$1"
  local sel="${f[0]}" lua
  if [ "${f[1]:-}" = "disable" ]; then
    lua="hl.monitor({ output = $(lua_str "$sel"), disabled = true })"
  else
    lua="hl.monitor({ output = $(lua_str "$sel"), disabled = false"
    lua+=", mode = $(lua_str "${f[1]:-preferred}")"
    lua+=", position = $(lua_str "${f[2]:-auto}")"
    lua+=", scale = ${f[3]:-1}"
    [ "${f[4]:-}" = "bitdepth" ] && lua+=", bitdepth = ${f[5]:-8}"
    lua+=" })"
  fi
  hyprctl eval "$lua" >/dev/null 2>&1
}

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
        # Rank refresh by its nominal value: the G9 advertises its 240 Hz modes as
        # 239.76 (5120x1440), 239.90 (2560x1440) and 239.97 (3840x1080), and a raw
        # float compare would crown 3840x1080 the "fastest" mode. Same tier, so
        # pixel count decides; the exact rate only breaks real ties.
        key = (round(r), w * h, r) if by_refresh else (w * h, round(r), r)
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
    hypr_monitor "$n,disable"
  done < <(all_names)
  sleep 1

  hypr_monitor "$primary,$mode,0x0,1"
  sleep 1

  if [ "$(sysfs_enabled "$primary")" = "enabled" ]; then
    log "ok: $primary is enabled"
    return 0
  fi

  log "WARNING: $primary did not commit at $mode; retrying at preferred"
  hypr_monitor "$primary,preferred,0x0,1"
  sleep 1
  if [ "$(sysfs_enabled "$primary")" = "enabled" ]; then
    log "ok: $primary is enabled at preferred"
    return 0
  fi

  log "ERROR: could not enable $primary; asking hyprland to reload its config"
  hyprctl reload >/dev/null 2>&1
  return 1
}

# Secondary placement. One output (EDID prefix, same as hyprland.lua) sits to
# the RIGHT of the primary, bottom edges flush. Everyone else sits ABOVE, bottom
# edges flush with the primary's top, packed right-to-left from the primary's
# right edge. On this desk that is ASUS VG245 beside the G9 and Samsung S27E590
# in the G9's top-right corner, in every primary mode.
# Emits one "name,WxH@R,XxY" line per secondary (or auto-up / auto-right when a
# mode or the primary's geometry cannot be parsed).
RIGHT_OF_PRIMARY="${TEONIX_RIGHT_OF_PRIMARY:-ASUSTek COMPUTER INC VG245}"

plan_secondaries() {
  local f
  f="$(snapshot)" || return 1
  python3 - "$f" "$1" "$2" "$CAP" "$PXRATE" "$RIGHT_OF_PRIMARY" "$SEC_CAP" <<'PY'
import json, re, sys
monitors = json.load(open(sys.argv[1]))
primary, pmode = sys.argv[2], sys.argv[3]
cap = float(sys.argv[4]) if sys.argv[4] else None
px = float(sys.argv[5]) if sys.argv[5] else None
right_prefix = sys.argv[6]
sec_cap = float(sys.argv[7]) if sys.argv[7] else None
if sec_cap is not None:
    cap = sec_cap if cap is None else min(cap, sec_cap)

g = re.match(r"(\d+)x(\d+)@", pmode)
xright = int(g.group(1)) if g else None
pheight = int(g.group(2)) if g else None

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
beside = [m for m in secondaries if m.get("description", "").startswith(right_prefix)]
above = [m for m in secondaries if m not in beside]
above.sort(key=lambda m: m.get("description", ""), reverse=True)

def emit(m, x, y, fallback):
    b = best(m)
    if b is None or xright is None:
        print("%s,preferred,%s" % (m["name"], fallback))
        return
    w, h, r = b
    print("%s,%dx%d@%g,%dx%d" % (m["name"], w, h, r, x, y))

for m in beside:
    b = best(m)
    y = (pheight - b[1]) if (b is not None and pheight is not None) else 0
    emit(m, xright, y, "auto-right")
for m in above:
    b = best(m)
    if b is None or xright is None:
        print("%s,preferred,auto-up" % m["name"])
        continue
    w, h, r = b
    x = xright - w
    emit(m, x, -h, "auto-up")
    xright = x
PY
  rm -f "$f"
}

# Is the live layout already what `ultrawide` would produce? Primary at its best
# allowed area mode at 0x0, every secondary enabled at the mode and position
# plan_secondaries wants. Used by `follow` so a hotplug that Hyprland's own config
# rules already handled correctly (PIP -> full) costs no extra modeset.
layout_is_current() {
  local f primary mode plan
  primary="$(pick_primary)"
  [ -n "$primary" ] || return 1
  mode="$(best_mode "$primary" "" area)"
  plan="$(plan_secondaries "$primary" "$mode")"
  f="$(snapshot)" || return 1
  python3 - "$f" "$primary" "$mode" "$plan" <<'PY'
import json, re, sys
monitors = {m["name"]: m for m in json.load(open(sys.argv[1]))}
primary, pmode, plan = sys.argv[2], sys.argv[3], sys.argv[4]

def parse(s):
    g = re.match(r"(\d+)x(\d+)@([\d.]+)", s or "")
    return (int(g.group(1)), int(g.group(2)), float(g.group(3))) if g else None

def at(m, w, h, r, x, y):
    if m.get("disabled"):
        return False
    if (m.get("width"), m.get("height")) != (w, h):
        return False
    if abs(float(m.get("refreshRate", 0)) - r) > 1.5:
        return False
    return (m.get("x"), m.get("y")) == (x, y)

p = monitors.get(primary)
want = parse(pmode)
if p is None or want is None or not at(p, *want, 0, 0):
    sys.exit(1)
for line in plan.splitlines():
    if not line.strip():
        continue
    name, mode, pos = line.split(",")
    m = monitors.get(name)
    want = parse(mode)
    g = re.match(r"(-?\d+)x(-?\d+)$", pos)
    if m is None or want is None or not g:
        sys.exit(1)  # "preferred"/"auto-*" fallbacks: cannot verify, so re-apply
    if not at(m, *want, int(g.group(1)), int(g.group(2))):
        sys.exit(1)
sys.exit(0)
PY
  local rc=$?
  rm -f "$f"
  return $rc
}

# Primary at its best allowed mode (by KEY) at 0x0, secondaries re-anchored
# (ASUS to the right, the rest above). Both live layouts go through here; the
# pixel-rate ban in best_mode means nothing this GPU cannot survive is ever
# requested. A third argument "noverify" skips verify-or-revert (used by
# `follow`, where a mid-hotplug snapshot must not be allowed to trigger `safe`).
apply_multi() {
  local key="$1" label="$2" verify="${3:-verify}"
  have_hypr || { log "hyprland not reachable"; return 1; }

  local primary mode line
  primary="$(pick_primary)"
  [ -n "$primary" ] || { log "no outputs reported"; return 1; }

  # No refresh cap on the primary: the pixel-rate budget is the real limit.
  mode="$(best_mode "$primary" "" "$key")"
  log "$label: $primary at $mode; ASUS to the right, remaining outputs above"

  # Hyprland re-validates the layout after every single monitor rule change, and a
  # transient overlap earns a sticky "Monitor DP-2 overlaps with other monitors"
  # banner. So order the steps so that no intermediate layout overlaps: when the
  # primary GROWS (2560 -> 5120 wide) the secondaries are anchored to the new,
  # wider edge, which is clear of both the old and the new footprint, so move them
  # first; when it SHRINKS the old anchors are clear of the new footprint, so
  # shrink first and pull the secondaries in afterwards.
  local secondaries old_w new_w
  secondaries="$(plan_secondaries "$primary" "$mode")"
  old_w="$(current_mode "$primary")"; old_w="${old_w%%x*}"
  new_w="${mode%%x*}"
  case "$old_w" in *[!0-9]*|"") old_w=0 ;; esac
  case "$new_w" in *[!0-9]*|"") new_w=0 ;; esac

  place_secondaries() {
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      hypr_monitor "$line,1,bitdepth,8"
    done <<< "$secondaries"
  }

  if [ "$new_w" -gt "$old_w" ]; then
    place_secondaries
    hypr_monitor "$primary,$mode,0x0,1,bitdepth,8"
  else
    hypr_monitor "$primary,$mode,0x0,1,bitdepth,8"
    place_secondaries
  fi

  [ "$verify" = "noverify" ] && return 0
  cmd_verify_or_revert "$primary" "$mode"
}

# Largest picture: most pixels first, then refresh (5120x1440@240 on the G9 with the Arc).
cmd_ultrawide()   { apply_multi area "ultrawide mode"; }
# Fastest picture: highest refresh first, then pixels (also 5120x1440@240 on the G9 with the Arc).
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

# One `follow` pass: if the live layout is not what ultrawide would build, build
# it. No verify-or-revert here — a panel mid-reconnect must not collapse the desk
# to `safe`; the next monitoradded event gets another pass anyway.
follow_settle() {
  have_hypr || return 0
  if layout_is_current; then
    log "follow: layout already correct"
    return 0
  fi
  log "follow: outputs changed, re-anchoring layout"
  apply_multi area "follow" noverify
}

# Are the secondaries anchored to the primary's CURRENT footprint? Positions
# only — the primary's mode is whatever it is (Super+Ctrl+S may have chosen the
# 120 fallback on purpose, and that must not be undone). Used by the periodic
# reconcile in `follow`, so a hotplug whose event was missed or arrived after
# the debounce still ends in a contiguous layout within a few seconds.
anchors_current() {
  local f primary mode plan
  primary="$(pick_primary)"
  [ -n "$primary" ] || return 0
  mode="$(current_mode "$primary")"
  case "$mode" in [0-9]*x[0-9]*@*) ;; *) return 0 ;; esac
  plan="$(plan_secondaries "$primary" "$mode")"
  f="$(snapshot)" || return 0
  python3 - "$f" "$primary" "$plan" <<'PY'
import json, re, sys
monitors = {m["name"]: m for m in json.load(open(sys.argv[1]))}
p = monitors.get(sys.argv[2])
if p is None or p.get("disabled") or (p.get("x"), p.get("y")) != (0, 0):
    sys.exit(1)
for line in sys.argv[3].splitlines():
    if not line.strip():
        continue
    name, _mode, pos = line.split(",")
    m = monitors.get(name)
    g = re.match(r"(-?\d+)x(-?\d+)$", pos)
    if m is None or not g:
        sys.exit(0)  # cannot verify; do not thrash
    if m.get("disabled") or (m.get("x"), m.get("y")) != (int(g.group(1)), int(g.group(2))):
        sys.exit(1)
sys.exit(0)
PY
  local rc=$?
  rm -f "$f"
  return $rc
}

# Re-place the secondaries around the primary's current mode, nothing else.
follow_reanchor() {
  local primary mode line
  primary="$(pick_primary)"
  [ -n "$primary" ] || return 0
  mode="$(current_mode "$primary")"
  log "follow: secondaries off their anchors for $primary at $mode; re-placing"
  # Same mode, so this is a move at most, never a modeset.
  hypr_monitor "$primary,$mode,0x0,1,bitdepth,8"
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    hypr_monitor "$line,1,bitdepth,8"
  done < <(plan_secondaries "$primary" "$mode")
}

# Scrolling-layout column widths are fractions of the workspace width, so a
# 5120 -> 2560 primary squashes every column by half. scroll-columns.py keeps
# a per-window pixel-width snapshot (taken on the quiet ticks) and re-issues
# each column at intended_px / new_width after a resize.
COLUMNS_PY="$(dirname "$(readlink -f "$0")")/scroll-columns.py"
follow_columns() {
  local what="$1" primary
  [ -f "$COLUMNS_PY" ] || return 0
  primary="$(pick_primary)"
  [ -n "$primary" ] || return 0
  python3 "$COLUMNS_PY" "$what" "$primary" 2>&1 | while IFS= read -r line; do log "$line"; done
}

# Quiet-time tick: anchors right? Column snapshot current?
follow_tick() {
  have_hypr || return 0
  anchors_current || follow_reanchor
  follow_columns snapshot
}

# Keep the layout right across hotplugs. The G9 toggling PIP is a real DP
# disconnect + reconnect with a *different EDID* (2-block, tops out at
# 2560x1440@120), so Hyprland's config pin (5120x1440@240) no longer exists and it
# falls back to the panel's preferred mode — but the secondaries keep their
# 5120-wide anchors from hyprland.lua and end up floating 2560 px away, with no
# edge to drag the cursor across. Listen on Hyprland's event socket, and after
# every monitoradded burst re-run the ultrawide placement (best advertised mode
# for the primary, secondaries re-anchored to its real width). PIP -> full is
# handled by Hyprland's own rules already; layout_is_current makes that a no-op.
cmd_follow() {
  local sig="${HYPRLAND_INSTANCE_SIGNATURE:-}"
  local sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/$sig/.socket2.sock"
  [ -n "$sig" ] || { log "follow: HYPRLAND_INSTANCE_SIGNATURE is unset"; return 1; }
  command -v socat >/dev/null 2>&1 || { log "follow: socat not found"; return 1; }

  # exec-once gives this no useful stderr; keep a per-session log so a layout
  # that "just got ruined" can be read back afterwards.
  mkdir -p "$STATE_DIR"
  exec 2>>"$STATE_DIR/follow.log"
  log() { printf '%s display-safe: %s\n' "$(date +%T)" "$*" >&2; }

  log "follow started (pid $$)"
  # A session that starts while the G9 is already in PIP mode gets the same
  # treatment as a live toggle.
  follow_settle
  follow_columns snapshot

  local ev rc
  while :; do
    if [ -S "$sock" ]; then
      while :; do
        IFS= read -r -t 5 ev; rc=$?
        if [ "$rc" -gt 128 ]; then
          # 5 s with no event at all: quiet time, reconcile and snapshot.
          follow_tick
          continue
        fi
        [ "$rc" -eq 0 ] || break   # socat gone
        case "$ev" in monitoradded*|monitorremoved*) ;; *) continue ;; esac
        log "follow: event ${ev%%>>*}"
        case "$ev" in monitorremoved*) continue ;; esac
        # Debounce: a reconnect emits several events and the panel needs a
        # moment to settle on its mode. Drain whatever else arrives meanwhile.
        sleep 1.5
        while IFS= read -r -t 0.2 ev; do :; done
        follow_settle
        sleep 0.5
        follow_columns rescale
      done < <(socat -u UNIX-CONNECT:"$sock" - 2>/dev/null)
    fi
    have_hypr || { log "follow: hyprland is gone, exiting"; return 0; }
    sleep 2
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
    hypr_monitor "$rule"
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
  follow)              cmd_follow ;;
  save-and-deescalate) cmd_save_and_deescalate ;;
  restore)             cmd_restore ;;
  *)
    printf 'usage: %s {safe|ultrawide|highrefresh|verify-or-revert SEL|watchdog|follow|save-and-deescalate|restore}\n' \
      "$(basename "$0")" >&2
    exit 2
    ;;
esac
