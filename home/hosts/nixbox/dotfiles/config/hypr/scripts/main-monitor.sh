#!/usr/bin/env bash
# Move the "main" output: the bar, dock and overlays, plus every workspace that is
# pinned to main, all follow to another monitor.
#
# No connector name, monitor model or card index appears here. Outputs come from
# `hyprctl monitors`, the set of workspaces belonging to main comes from
# `hyprctl workspacerules`, and Quickshell follows through its `mainmonitor` IPC
# handler. No monitor's mode is ever touched: this is purely about which output is
# designated main, so it is independent of resolution and refresh.
#
# Workspaces that were never pinned to main stay where they are, so the receiving
# monitor keeps its own workspaces and gains main's on top.
#
# Modes:
#   toggle       bounce between the largest panel (G9) and the ASUS on its right
#   next         advance to the next output, in description order
#   set SEL      make SEL main (a connector name, or a `desc:` prefix)
#   status       report the current main and what `toggle` would do
#
# Caveat: `hyprctl reload` re-reads the config and pins the workspace rules back to
# their configured output. Workspaces already moved stay put; press the bind again
# to line everything up.
set -uo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/teonix-display"
CUR_FILE="$STATE_DIR/main-monitor"
PREV_FILE="$STATE_DIR/main-monitor.prev"
QS_IPC="$HOME/.config/quickshell/scripts/qs-live-ipc.sh"
# Super+Esc pair: EDID prefix, same string as hyprland.conf / display-safe.sh.
# Not a connector name — any port.
TOGGLE_PARTNER="${TEONIX_MAIN_TOGGLE_PARTNER:-ASUSTek COMPUTER INC VG245}"

log() { printf 'main-monitor: %s\n' "$*" >&2; }

have_hypr() { hyprctl monitors -j >/dev/null 2>&1; }

# `hyprctl … -j` cannot be piped into a `python3 - <<HEREDOC`, because the heredoc
# is already occupying stdin. Snapshot to a file and pass the path instead.
snap() {
  local f
  f="$(mktemp "${TMPDIR:-/tmp}/teonix-mainmon.XXXXXX")" || return 1
  if ! hyprctl "$1" -j >"$f" 2>/dev/null || [ ! -s "$f" ]; then
    rm -f "$f"
    return 1
  fi
  printf '%s' "$f"
}

# Active outputs, ordered by description so the cycle is stable across reboots and
# re-cabling. A disabled output cannot host the bar, so `monitors` (not
# `monitors all`) is deliberate here.
ordered_names() {
  local f
  f="$(snap monitors)" || return 1
  python3 - "$f" <<'PY'
import json, sys
mons = json.load(open(sys.argv[1]))
for m in sorted(mons, key=lambda m: (m.get("description", ""), m["name"])):
    print(m["name"])
PY
  rm -f "$f"
}

# Fallback main when there is no state yet: the same pick Quickshell makes on its
# own, i.e. the largest panel by pixel count.
largest_name() {
  local f
  f="$(snap monitors)" || return 1
  python3 - "$f" <<'PY'
import json, sys
mons = json.load(open(sys.argv[1]))
best = max(mons, key=lambda m: (m["width"] * m["height"], m.get("description", "")))
print(best["name"])
PY
  rm -f "$f"
}

describe() {
  local f
  f="$(snap monitors)" || return 1
  python3 - "$f" "$1" <<'PY'
import json, sys
for m in json.load(open(sys.argv[1])):
    if m["name"] == sys.argv[2]:
        print(m.get("description", ""))
        break
PY
  rm -f "$f"
}

resolve_name() {
  local sel="$1" f
  case "$sel" in
    desc:*)
      f="$(snap monitors)" || return 1
      python3 - "$f" "${sel#desc:}" <<'PY'
import json, sys
for m in json.load(open(sys.argv[1])):
    if m.get("description", "").startswith(sys.argv[2]):
        print(m["name"])
        break
PY
      rm -f "$f"
      ;;
    *) printf '%s\n' "$sel" ;;
  esac
}

is_live() {
  local n
  while read -r n; do
    [ "$n" = "$1" ] && return 0
  done < <(ordered_names)
  return 1
}

current_main() {
  local saved=""
  [ -r "$CUR_FILE" ] && saved="$(tr -d '[:space:]' < "$CUR_FILE")"
  if [ -n "$saved" ] && is_live "$saved"; then
    printf '%s\n' "$saved"
    return 0
  fi
  largest_name
}

# Workspaces pinned to the given output, as "<workspaceString>\t<is default>".
# Read from the live rules rather than a hardcoded range, so the config stays the
# single place that decides which workspaces belong to main.
rules_on() {
  local target_name="$1" mf rf
  mf="$(snap monitors)" || return 1
  rf="$(snap workspacerules)" || { rm -f "$mf"; return 1; }
  python3 - "$mf" "$rf" "$target_name" <<'PY'
import json, sys
mons = json.load(open(sys.argv[1]))
rules = json.load(open(sys.argv[2]))
want = sys.argv[3]

by_name = {m["name"]: m for m in mons}
target = by_name.get(want)
if target is None:
    sys.exit(0)


def selects_target(sel):
    if not sel:
        return False
    if sel.startswith("desc:"):
        return target.get("description", "").startswith(sel[len("desc:"):])
    return sel == want


for r in rules:
    if not selects_target(r.get("monitor", "")):
        continue
    ws = str(r.get("workspaceString", ""))
    if not ws:
        continue
    print("%s\t%d" % (ws, 1 if r.get("default") else 0))
PY
  rm -f "$mf" "$rf"
}

# Workspace ids that exist right now, one per line.
live_workspaces() {
  local f
  f="$(snap workspaces)" || return 1
  python3 - "$f" <<'PY'
import json, sys
for w in json.load(open(sys.argv[1])):
    print(w["id"])
PY
  rm -f "$f"
}

make_main() {
  local target="$1" source ws isdef desc rule rule_monitor id moved=0
  source="$(current_main)"

  if [ "$target" = "$source" ]; then
    log "$target is already main"
    return 0
  fi
  if ! is_live "$target"; then
    log "$target is not an active output; nothing to do"
    return 1
  fi

  desc="$(describe "$target")"
  if [ -n "$desc" ]; then
    rule_monitor="desc:$desc"
  else
    rule_monitor="$target"
  fi

  local -a existing=()
  while read -r id; do
    [ -n "$id" ] && existing+=("$id")
  done < <(live_workspaces)

  # Re-point the rules first, so workspaces created later also land on the new
  # main, then move the ones that already exist.
  while IFS=$'\t' read -r ws isdef; do
    [ -z "$ws" ] && continue
    rule="$ws, monitor:$rule_monitor"
    [ "$isdef" = "1" ] && rule="$rule, default:true"
    hyprctl keyword workspace "$rule" >/dev/null 2>&1

    for id in "${existing[@]}"; do
      if [ "$id" = "$ws" ]; then
        hyprctl dispatch moveworkspacetomonitor "$ws" "$target" >/dev/null 2>&1
        moved=$((moved + 1))
        break
      fi
    done
  done < <(rules_on "$source")

  mkdir -p "$STATE_DIR"
  printf '%s\n' "$source" > "$PREV_FILE"
  printf '%s\n' "$target" > "$CUR_FILE"

  # Quickshell places the bar on whatever it considers main; tell it explicitly.
  if [ -x "$QS_IPC" ] || [ -r "$QS_IPC" ]; then
    bash "$QS_IPC" mainmonitor set "$target" >/dev/null 2>&1 \
      || log "could not reach quickshell; bar will follow on its next start"
  fi

  hyprctl dispatch focusmonitor "$target" >/dev/null 2>&1
  log "main is now $target${desc:+ ($desc)}, $moved workspace(s) moved from $source"
}

next_after() {
  local cur="$1" first="" prev="" n
  while read -r n; do
    [ -z "$first" ] && first="$n"
    [ "$prev" = "$cur" ] && { printf '%s\n' "$n"; return 0; }
    prev="$n"
  done < <(ordered_names)
  printf '%s\n' "$first"
}

cmd_toggle() {
  local cur partner largest
  cur="$(current_main)"
  partner="$(resolve_name "desc:$TOGGLE_PARTNER")"
  largest="$(largest_name)"

  # Dedicated pair: G9 (largest) ↔ ASUS. If the ASUS is unplugged, fall back to
  # prev / next-in-description so the bind still does something.
  if [ -n "$partner" ] && is_live "$partner"; then
    if [ "$cur" = "$partner" ]; then
      make_main "$largest"
    else
      make_main "$partner"
    fi
    return
  fi

  local back=""
  [ -r "$PREV_FILE" ] && back="$(tr -d '[:space:]' < "$PREV_FILE")" || back=""
  if [ -n "$back" ] && [ "$back" != "$cur" ] && is_live "$back"; then
    make_main "$back"
  else
    make_main "$(next_after "$cur")"
  fi
}

cmd_status() {
  local cur
  cur="$(current_main)"
  printf 'main:   %s (%s)\n' "$cur" "$(describe "$cur")"
  printf 'order:  %s\n' "$(ordered_names | tr '\n' ' ')"
  printf 'pinned: %s\n' "$(rules_on "$cur" | cut -f1 | tr '\n' ' ')"
}

have_hypr || { log "hyprland not reachable"; exit 1; }

case "${1:-}" in
  toggle) cmd_toggle ;;
  next)   make_main "$(next_after "$(current_main)")" ;;
  set)    shift; make_main "$(resolve_name "${1:-}")" ;;
  status) cmd_status ;;
  *)
    printf 'usage: %s {toggle|next|set SEL|status}\n' "$(basename "$0")" >&2
    exit 2
    ;;
esac
