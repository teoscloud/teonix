#!/usr/bin/env bash
# Resolve buschain-ctl for Quickshell mixer panel.
set -euo pipefail

try_bins=(
  "buschain-ctl"
  "${HOME}/Projects/buschain-control/target/debug/buschain-ctl"
  "${HOME}/Projects/buschain-control/target/release/buschain-ctl"
  "${HOME}/.local/bin/buschain-ctl"
)

for b in "${try_bins[@]}"; do
  if [[ "$b" == /* ]]; then
    if [[ -x "$b" ]]; then
      exec "$b" "$@"
    fi
  elif command -v "$b" >/dev/null 2>&1; then
    exec "$b" "$@"
  fi
done

echo '{"error":"buschain-ctl not found — run: cd ~/Projects/buschain-control && nix develop"}' >&2
exit 127
