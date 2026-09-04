#!/usr/bin/env bash
# Battle.net on Fedora Asahi: 4K muvm + FEX + x86 GE-Proton. Never Steam, never
# host aarch64 Proton (RPC_S_SERVER_UNAVAILABLE hang, Proton #10011).
# CEF flags are frozen — see teonix-battlenet-lib.sh.
set -euo pipefail

HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
# shellcheck source=teonix-muvm-common.sh
source "$HERE/teonix-muvm-common.sh"
# shellcheck source=teonix-battlenet-lib.sh
source "$HERE/teonix-battlenet-lib.sh"

teonix_host_fedora_env

case ${1:-} in
  kill)
    exec "$HERE/teonix-battlenet-kill.sh"
    ;;
  doctor)
    doctor
    exit 0
    ;;
  wow)
    shift
    teonix_need_muvm
    teonix_ram_gate 4500
    teonix_muvm_lock "WoW Classic"
    { echo "==== $(date -Iseconds) pid=$$ direct-wow ===="; } >>"$BNET_LOG"
    trap 'exec 9>&- 2>/dev/null || true' EXIT
    ensure_x86_proton || {
      echo "teonix: Proton unpack failed. See $BNET_LOG" >&2
      exit 1
    }
    run_wow_direct
    exit $?
    ;;
esac

teonix_need_muvm
teonix_ram_gate 4500
teonix_muvm_lock Battle.net

{
  echo "==== $(date -Iseconds) pid=$$ ===="
} >>"$BNET_LOG"

trap 'exec 9>&- 2>/dev/null || true' EXIT

ensure_x86_proton || {
  echo "teonix: Proton unpack failed. See $BNET_LOG" >&2
  exit 1
}

launch_client() {
  local launcher=$1
  write_client_config
  write_wow_classic_config
  echo "Launching Battle.net."
  run_in_guest "$launcher" "${CEF_ARGS[@]}"
}

if launcher=$(find_launcher); then
  launch_client "$launcher"
  exit $?
fi

setup=$(stage_installer) || exit 1
echo "Battle.net is not installed yet — running the Windows setup (no language dialog)."
run_in_guest "$setup" --lang=enUS --installpath='C:\Program Files (x86)\Battle.net' "${CEF_ARGS[@]}" || true

if launcher=$(find_launcher); then
  echo "Setup finished. Battle.net is in the application launcher."
  for _ in $(seq 1 30); do
    teonix_muvm_busy || break
    sleep 0.4
  done
  launch_client "$launcher"
  exit $?
fi

echo "teonix: setup exited without Battle.net.exe — see $BNET_LOG" >&2
exit 1
