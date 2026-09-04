#!/usr/bin/env bash
# One muvm, no Fedora PyQt splash, no second copy.
set -euo pipefail

HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
# shellcheck source=teonix-muvm-common.sh
source "$HERE/teonix-muvm-common.sh"
teonix_host_fedora_env
teonix_need_muvm

log="${XDG_STATE_HOME:-$HOME/.local/state}/teonix-steam.log"
mkdir -p "$(dirname "$log")"

steam_up() {
  pgrep -f 'steamwebhelper' >/dev/null 2>&1 \
    || pgrep -f '/usr/bin/python3 /usr/bin/steam' >/dev/null 2>&1 \
    || pgrep -f '/Steam/steam.sh' >/dev/null 2>&1
}

if steam_up; then
  echo "Steam is already running — not starting another muvm." >&2
  exit 0
fi

teonix_ram_gate 1536
teonix_muvm_lock Steam

# Prefer the bootstrapped client. bin_steam.sh re-extracts and looks like a loop.
if [[ -f $HOME/.local/share/Steam/steam.sh ]]; then
  launcher=$HOME/.local/share/Steam/steam.sh
elif [[ -f $HOME/.local/share/fex-steam/steam-launcher/bin_steam.sh ]]; then
  launcher=$HOME/.local/share/fex-steam/steam-launcher/bin_steam.sh
else
  echo "Steam client is not bootstrapped — falling back to /usr/bin/steam" >&2
  exec /usr/bin/steam "$@"
fi

{
  echo "==== $(date -Iseconds) launcher=$launcher args=$* ===="
} >>"$log"

# Do not pass -cef-force-occlusion: it was for Big Picture and makes CEF
# treat the window as hidden, which restarts steamwebhelper in a loop.
cmd=$(printf '%q ' "$launcher" "$@")
exec muvm -- FEXBash -c "$cmd" >>"$log" 2>&1
