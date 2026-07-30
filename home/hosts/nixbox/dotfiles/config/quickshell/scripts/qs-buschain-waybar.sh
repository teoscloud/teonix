#!/usr/bin/env bash
# Resolve buschain status for Quickshell VolumePill.
# Prefer buschain-ctl status (Master HW). Never use @DEFAULT_SINK@ as HW —
# under BusChain that is often a track bus stuck at 100%.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CTL_WRAP="${SCRIPT_DIR}/qs-buschain-ctl.sh"

resolve_ctl() {
  if [[ -x "$CTL_WRAP" ]]; then
    printf '%s\n' "$CTL_WRAP"
    return 0
  fi
  local b
  for b in \
    "buschain-ctl" \
    "${HOME}/Projects/buschain-control/target/debug/buschain-ctl" \
    "${HOME}/Projects/buschain-control/target/release/buschain-ctl" \
    "${HOME}/.local/bin/buschain-ctl"
  do
    if [[ "$b" == /* ]]; then
      [[ -x "$b" ]] && { printf '%s\n' "$b"; return 0; }
    elif command -v "$b" >/dev/null 2>&1; then
      command -v "$b"
      return 0
    fi
  done
  return 1
}

find_buschain_waybar() {
  local b
  for b in \
    "buschain-waybar" \
    "${HOME}/.local/bin/buschain-waybar" \
    "${HOME}/Projects/buschain-control/packaging/waybar/buschain-waybar" \
    "${HOME}/.config/waybar/buschain-waybar.sh" \
    "${HOME}/Projects/buschain-control/packaging/waybar/buschain-waybar.sh"
  do
    if [[ "$b" == /* ]]; then
      [[ -x "$b" ]] && { printf '%s\n' "$b"; return 0; }
    elif command -v "$b" >/dev/null 2>&1; then
      command -v "$b"
      return 0
    fi
  done
  return 1
}

# Last-resort: Master HW sink from mixer JSON, else fail soft at 0.
pactl_master_hw_status() {
  local ctl sink mute vol muted class
  ctl=$(resolve_ctl || true)
  sink=""
  if [[ -n "${ctl:-}" ]]; then
    sink=$("$ctl" mixer 2>/dev/null | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get("status", {}).get("master_hw") or "")
except Exception:
    pass
' 2>/dev/null || true)
  fi
  if [[ -z "$sink" ]]; then
    printf '{"percentage":0,"muted":false,"class":"offline","tooltip":"buschain offline"}\n'
    return
  fi
  mute=$(pactl get-sink-mute "$sink" 2>/dev/null | awk '{print $2}' || true)
  vol=$(pactl get-sink-volume "$sink" 2>/dev/null | grep -oE '[0-9]+%' | head -1 | tr -d '%' || true)
  vol=${vol:-0}
  (( vol > 100 )) && vol=100
  muted=false
  class="normal"
  if [[ "$mute" == "yes" ]]; then
    muted=true
    class="muted"
  fi
  printf '{"percentage":%s,"muted":%s,"class":"%s","tooltip":"Master HW (pactl)"}\n' "$vol" "$muted" "$class"
}

cmd="${1:-status}"
ctl=$(resolve_ctl || true)
waybar=$(find_buschain_waybar || true)

case "$cmd" in
  status)
    # 1) buschain-ctl status — canonical Master HW JSON for the pill
    if [[ -n "${ctl:-}" ]]; then
      if out=$("$ctl" status 2>/dev/null); then
        if [[ "$out" == *'"percentage"'* && "$out" != *'"class":"offline"'* ]]; then
          printf '%s\n' "$out"
          exit 0
        fi
      fi
    fi
    # 2) packaging waybar helper (same IPC)
    if [[ -n "${waybar:-}" ]]; then
      if out=$("$waybar" status 2>/dev/null); then
        if [[ "$out" == *'"percentage"'* && "$out" != *'"class":"offline"'* ]]; then
          printf '%s\n' "$out"
          exit 0
        fi
      fi
    fi
    pactl_master_hw_status
    ;;
  up)
    if [[ -n "${ctl:-}" ]]; then
      "$ctl" hw-vol up >/dev/null 2>&1 || true
    elif [[ -n "${waybar:-}" ]]; then
      "$waybar" up >/dev/null 2>&1 || true
    fi
    ;;
  down)
    if [[ -n "${ctl:-}" ]]; then
      "$ctl" hw-vol down >/dev/null 2>&1 || true
    elif [[ -n "${waybar:-}" ]]; then
      "$waybar" down >/dev/null 2>&1 || true
    fi
    ;;
  *)
    echo "usage: qs-buschain-waybar.sh status|up|down" >&2
    exit 2
    ;;
esac
