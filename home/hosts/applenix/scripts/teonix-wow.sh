#!/usr/bin/env bash
# WoW Classic without Battle.net: the game's own login screen, same prefix and
# same 4K muvm + FEX guest. This is the repair path — the normal route is
# teonix-battlenet and the Play button.
set -euo pipefail
HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
exec "$HERE/teonix-battlenet.sh" wow "$@"
