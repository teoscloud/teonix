#!/usr/bin/env bash
# Toggle the Quickshell BusChain mixer panel (falls back to egui popup).
set -euo pipefail

if [[ "${BUSCHAIN_CONTROL_QS_MIXER:-}" == "1" || "${BUSCHAIN_CONTROL_QS_MIXER:-}" == "true" ]]; then
  if command -v qs >/dev/null 2>&1; then
    if qs ipc call mixer toggle >/dev/null 2>&1; then
      exit 0
    fi
  fi
fi

# Fallback: egui portable popup (checkout debug/release, then PATH)
for bin in \
  "${BUSCHAIN_CONTROL:-}" \
  "${HOME}/Projects/buschain-control/target/debug/buschain-control" \
  "${HOME}/Projects/buschain-control/target/release/buschain-control" \
  "buschain-control"
do
  [[ -n "$bin" ]] || continue
  if [[ "$bin" == /* && -x "$bin" ]]; then
    exec env BUSCHAIN_CONTROL_SKIP_BOOTSTRAP=1 "$bin" --popup playback
  elif [[ "$bin" != /* ]] && command -v "$bin" >/dev/null 2>&1; then
    exec env BUSCHAIN_CONTROL_SKIP_BOOTSTRAP=1 "$bin" --popup playback
  fi
done

exit 1
