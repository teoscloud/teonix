#!/usr/bin/env bash
# WoW Classic Anniversary via the same muvm + prefix as Battle.net.
# Starts Battle.net for -launcherlogin / Agent, then WowClassic windowed D3D11.
set -euo pipefail

HERE=$(cd "$(dirname "$(readlink -f "$0")")" && pwd)
# shellcheck source=teonix-muvm-common.sh
source "$HERE/teonix-muvm-common.sh"
# shellcheck source=teonix-battlenet-lib.sh
source "$HERE/teonix-battlenet-lib.sh"

teonix_host_fedora_env
teonix_need_muvm
teonix_ram_gate 1536
teonix_muvm_lock "WoW Classic"

{
  echo "==== $(date -Iseconds) pid=$$ wow ===="
} >>"$BNET_LOG"

watch_checkpoint
watch_pid=$!
trap 'kill "$watch_pid" 2>/dev/null || true; exec 9>&- 2>/dev/null || true' EXIT

ensure_x86_proton || {
  echo "teonix: Proton unpack failed. See $BNET_LOG" >&2
  exit 1
}

launcher=$(find_launcher) || {
  echo "teonix: Battle.net is not installed. Run teonix-battlenet once first." >&2
  exit 1
}

[[ -f $WOW_CLASSIC_EXE ]] || {
  echo "teonix: WowClassic.exe missing under _anniversary_." >&2
  echo "teonix: open Battle.net, install WoW Classic Anniversary, then retry." >&2
  exit 1
}

write_desktop
write_client_config
write_wow_classic_config

pre_login=$(set +o pipefail; grep -h 'Logged into Battle.net successfully' "$BNET_USER_LOGS"/battle.net-*.log 2>/dev/null | wc -l)
pre_login=${pre_login// /}
pre_login=${pre_login:-0}

mem=$(wow_mem_mib)
cef=$(printf '%q ' "${CEF_ARGS[@]}")
proton_q=$(printf '%q' "$PROTON_DIR/proton")
bnet_q=$(printf '%q' "$launcher")
wow_q=$(printf '%q' "$WOW_CLASSIC_EXE")
logs_q=$(printf '%q' "$BNET_USER_LOGS")

guest=$(cat <<EOF
$(guest_exports)
$(compat_exports "$launcher")
echo "Waiting for Battle.net login in the launcher window (not Brave)…"
$(inject_sidecar "$launcher")
PROTON_VERB=run $proton_q run $bnet_q $cef &
ok=0
for _ in \$(seq 1 240); do
  sleep 2
  now=\$(grep -h 'Logged into Battle.net successfully' $logs_q/battle.net-*.log 2>/dev/null | wc -l || true)
  now=\${now// /}
  if [[ -n \$now && \$now -gt $pre_login ]]; then
    ok=1
    break
  fi
done
if [[ \$ok -eq 1 ]]; then
  echo "Battle.net is logged in — launching WowClassic (windowed D3D11)."
else
  echo "Battle.net login not seen after ~8 minutes — launching WowClassic anyway."
fi
export PROTON_VERB=waitforexitandrun
# Virtual desktop forces an HWND on XWayland. Play/fullscreen exclusive does not.
exec $proton_q waitforexitandrun explorer.exe /desktop=WowClassic,1600x1000 $wow_q -launcherlogin -initialgamemode=bccfresh -uid wow_classic_anniversary -windowed
EOF
)

install_guest_xdg_open
bnet_log "wow muvm mem=${mem}M launcher=$launcher wow=$WOW_CLASSIC_EXE"
echo "Starting Battle.net then WoW Classic in one muvm (${mem} MiB, x86 $PROTON_TAG)."
echo "Leave the guest alone until WoW’s window is up. Do not click Play. Log: $BNET_LOG"
echo "Stay in the Battle.net window. A Brave localhost:0 tab is the callback — close it; the wrapper hands the ticket back."

muvm --mem="$mem" -- FEXBash -c "$guest"
