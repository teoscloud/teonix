#!/usr/bin/env bash
#
# applenix on Asahi Fedora — install Nix, then the teonix desktop.
#
# Fedora does not ship Nix. Run this as your normal user (it will sudo):
#
#   curl -fsSL https://raw.githubusercontent.com/teoscloud/teonix/main/hosts/applenix/fedora.sh | bash
#
# Idempotent: re-run after any failure; finished steps are skipped.
set -Eeuo pipefail

readonly VERSION=7
readonly SELF="applenix-fedora"
readonly CURL_CMD="curl -fsSL https://raw.githubusercontent.com/teoscloud/teonix/main/hosts/applenix/fedora.sh | bash"
readonly FLAKE_ATTR=applenix-fedora

TEONIX_REPO="${TEONIX_REPO:-https://github.com/teoscloud/teonix.git}"
TEONIX_DIR="${TEONIX_DIR:-$HOME/teonix}"

# Desktop bootstrap. steam is opt-in — FEX overlays are large and not needed
# to get Hyprland up.
readonly STEPS=(nix git repo identity switch gpu keyring session)
readonly EXTRA_STEPS=(steam)

say() { printf '%s\n' "$*"; }
ok() { printf '[ ok ] %s\n' "$*"; }
skip() { printf '[skip] %s\n' "$*"; }
runmsg() { printf '[ run] %s\n' "$*"; }
warn() { printf '[warn] %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

CURRENT_STEP=""
on_err() {
  local code=$?
  [[ -n $CURRENT_STEP ]] || exit "$code"
  printf '\nerror: step "%s" failed (exit %d)\n' "$CURRENT_STEP" "$code" >&2
  printf '       fix the cause and re-run:\n         %s\n' "$CURL_CMD" >&2
  exit "$code"
}
trap on_err ERR

have_nix() {
  command -v nix >/dev/null 2>&1 || [[ -x /nix/var/nix/profiles/default/bin/nix ]]
}

load_nix() {
  # Fresh installer leaves nix off PATH until a new login.
  if [[ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]]; then
    # shellcheck source=/dev/null
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  elif [[ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]]; then
    # shellcheck source=/dev/null
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
  fi
  command -v nix >/dev/null 2>&1 || [[ -x /nix/var/nix/profiles/default/bin/nix ]] \
    || return 1
  export PATH="${PATH}:/nix/var/nix/profiles/default/bin${HOME:+:$HOME/.nix-profile/bin}"
}

nix_str() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  printf '"%s"' "$s"
}

write_identity() {
  local user="${TEONIX_USER:-${USER:-$(id -un)}}"
  local home="${HOME:-/home/${user}}"
  [[ $user =~ ^[A-Za-z_][A-Za-z0-9_.-]*$ ]] \
    || die "refusing username $(printf %q "$user") — set TEONIX_USER= to a simple POSIX name"
  [[ -f $TEONIX_DIR/flake.nix ]] || die "$TEONIX_DIR/flake.nix is missing — run the repo step first"
  cat >"$TEONIX_DIR/local-identity.nix" <<EOF
{
  username = $(nix_str "$user");
  homeDirectory = $(nix_str "$home");
  projectdir = $(nix_str "$TEONIX_DIR");
}
EOF
}

probe_nix() { have_nix && load_nix; }
probe_git() { command -v git >/dev/null 2>&1; }
probe_repo() { [[ -f $TEONIX_DIR/flake.nix ]]; }
probe_identity() {
  local user="${TEONIX_USER:-${USER:-$(id -un)}}"
  [[ -f $TEONIX_DIR/local-identity.nix ]] \
    && grep -q "username = \"${user}\"" "$TEONIX_DIR/local-identity.nix"
}
probe_switch() { [[ -e $HOME/.local/state/home-manager/gcroots/current-home ]]; }
# /run/opengl-driver must point at the *current* generation's driver env, or
# Nix GL apps fall back to Fedora Mesa they cannot link against.
probe_gpu() {
  local want
  want=$(gpu_drivers_path) || return 1
  [[ -n $want ]] && [[ "$(readlink /run/opengl-driver 2>/dev/null)" == "$want" ]]
}
probe_session() {
  [[ -x /usr/local/bin/hyprland-nix-session ]] \
    && [[ -f /usr/local/share/wayland-sessions/hyprland-nix.desktop ]] \
    && [[ -f /etc/sddm.conf.d/10-teonix-hyprland.conf ]]
}
# Host gnome-keyring + PAM so SDDM unlocks the login keyring for every DE.
# Nix gnome-keyring cannot hook Fedora PAM; the host daemon is the one that
# owns org.freedesktop.secrets after login.
probe_keyring() {
  rpm -q gnome-keyring gnome-keyring-pam >/dev/null 2>&1 \
    && authselect current 2>/dev/null | grep -q with-pam-gnome-keyring
}

# Official Fedora Asahi Steam wrapper (muvm + FEX + Mesa overlays). Not Nix Steam.
probe_steam() {
  rpm -q steam >/dev/null 2>&1 && [[ -x /usr/bin/steam ]]
}

known_step() {
  local want=$1 x
  for x in "${STEPS[@]}" "${EXTRA_STEPS[@]}"; do
    [[ $x == "$want" ]] && return 0
  done
  return 1
}

step_nix() {
  if have_nix && load_nix; then
    skip "nix — $(nix --version 2>/dev/null || echo already installed)"
    return 0
  fi

  runmsg "nix — Fedora does not ship this; installing the Determinate daemon"
  command -v curl >/dev/null || die "curl is missing — 'sudo dnf install -y curl'"
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm

  load_nix || die "Nix installed but is not on PATH. Open a new terminal and re-run: $CURL_CMD"
  ok "nix — $(nix --version)"
}

step_git() {
  if command -v git >/dev/null; then
    skip "git"
    return 0
  fi
  runmsg "git — installing with dnf"
  sudo dnf install -y git
  command -v git >/dev/null || die "git still missing after dnf install"
  ok "git"
}

step_repo() {
  if [[ -d $TEONIX_DIR/.git ]]; then
    runmsg "repo — updating $TEONIX_DIR"
    git -C "$TEONIX_DIR" fetch --prune origin || warn "git fetch failed; working offline"
    local branch upstream
    branch=$(git -C "$TEONIX_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null || echo main)
    upstream=$(git -C "$TEONIX_DIR" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null \
      || echo "origin/$branch")
    git -C "$TEONIX_DIR" pull --ff-only "$upstream" 2>/dev/null \
      || git -C "$TEONIX_DIR" pull --ff-only origin "$branch" 2>/dev/null \
      || warn "could not fast-forward; using the checkout as-is"
    ok "repo — $TEONIX_DIR"
    return 0
  fi

  if [[ -e $TEONIX_DIR ]]; then
    die "$TEONIX_DIR exists and is not a git repo — move it or set TEONIX_DIR="
  fi

  runmsg "repo — cloning $TEONIX_REPO"
  mkdir -p "$(dirname "$TEONIX_DIR")"
  git clone "$TEONIX_REPO" "$TEONIX_DIR"
  ok "repo — cloned to $TEONIX_DIR"
}

step_identity() {
  write_identity
  ok "identity — $(tr -d '\n' <"$TEONIX_DIR/local-identity.nix" | tr -s ' ')"
}

step_switch() {
  load_nix || die "nix is not available; re-run so step nix can finish"
  [[ -f $TEONIX_DIR/flake.nix ]] || die "$TEONIX_DIR/flake.nix is missing"

  runmsg "switch — home-manager $FLAKE_ATTR (first run downloads a lot)"
  cd "$TEONIX_DIR"
  nix run --accept-flake-config nixpkgs#home-manager -- switch -b bak \
    --flake "path:.#${FLAKE_ATTR}" \
    --option max-jobs 1
  ok "switch — #${FLAKE_ATTR}"
}

gpu_setup_bin() {
  local c
  for c in "$HOME/.nix-profile/bin/non-nixos-gpu-setup" \
           "/etc/profiles/per-user/${USER:-$(id -un)}/bin/non-nixos-gpu-setup"; do
    [[ -x $c ]] && { printf '%s\n' "$(readlink -f "$c")"; return 0; }
  done
  return 1
}

# The setup script symlinks /run/opengl-driver at the driver env it was built
# with; that target is the answer probe_gpu compares against.
gpu_drivers_path() {
  local bin
  bin=$(gpu_setup_bin) || return 1
  sed -n 's#^ln -sf \(/nix/store/[^ ]*\)/lib/tmpfiles.d/.*#\1#p' "$bin" \
    | head -1 \
    | { read -r pkg && [[ -n $pkg ]] && sed -n 's#^L+ /run/opengl-driver[[:space:]-]*\(/nix/store/[^ ]*\)$#\1#p' \
        "$pkg/lib/tmpfiles.d/non-nixos-gpu.conf"; }
}

step_gpu() {
  local bin
  bin=$(gpu_setup_bin) || die "non-nixos-gpu-setup is missing — run the switch step first"

  runmsg "gpu — pointing /run/opengl-driver at Nix Mesa (Asahi driver included)"
  # Nix Hyprland/kitty link Nix libglvnd, which searches /run/opengl-driver.
  # Without this, EGL cannot initialise and every Nix GL app dies.
  sudo "$bin"
  probe_gpu || warn "/run/opengl-driver is $(readlink /run/opengl-driver 2>/dev/null || echo unset) after setup"
  ok "gpu — $(readlink /run/opengl-driver 2>/dev/null || echo '/run/opengl-driver')"
}

step_keyring() {
  runmsg "keyring — host GNOME Keyring + PAM unlock (not KWallet) for every session"
  sudo dnf install -y gnome-keyring gnome-keyring-pam
  # SDDM uses password-auth/system-auth; this feature injects pam_gnome_keyring
  # so the login keyring is created and unlocked with the user password.
  sudo authselect enable-feature with-pam-gnome-keyring
  probe_keyring || warn "gnome-keyring PAM feature is not active yet"
  ok "keyring — gnome-keyring + authselect with-pam-gnome-keyring (re-login to unlock)"
}

step_session() {
  local user="${TEONIX_USER:-${USER:-$(id -un)}}"
  local trampoline=/usr/local/bin/hyprland-nix-session
  local local_sessions=/usr/local/share/wayland-sessions
  local system_sessions=/usr/share/wayland-sessions
  local sddm_dropin=/etc/sddm.conf.d/10-teonix-hyprland.conf
  local desktop

  runmsg "session — one-time greeter hook (stable Exec, no more sudo cp)"

  sudo mkdir -p /usr/local/bin "$local_sessions" "$system_sessions" /etc/sddm.conf.d
  sudo tee "$trampoline" >/dev/null <<'TRAMPOLINE'
#!/bin/sh
for c in \
  "$HOME/.nix-profile/bin/hyprland-nix-session" \
  "/etc/profiles/per-user/$USER/bin/hyprland-nix-session"
do
  if [ -x "$c" ]; then
    exec "$c" "$@"
  fi
done
echo "hyprland-nix-session not in the Home Manager profile — run updatehome" >&2
exit 1
TRAMPOLINE
  sudo chmod 755 "$trampoline"
  sudo chown "$user:$user" "$trampoline" "$local_sessions"

  desktop=$(cat <<'DESKTOP'
[Desktop Entry]
Name=Hyprland (Nix)
Comment=Hyprland from teonix Home Manager
Exec=/usr/local/bin/hyprland-nix-session
TryExec=/usr/local/bin/hyprland-nix-session
Type=Application
DesktopNames=Hyprland
DESKTOP
)
  printf '%s\n' "$desktop" | sudo tee "$local_sessions/hyprland-nix.desktop" >/dev/null
  printf '%s\n' "$desktop" | sudo tee "$local_sessions/hyprland.desktop" >/dev/null
  sudo cp "$local_sessions/hyprland-nix.desktop" "$system_sessions/hyprland-nix.desktop"
  sudo cp "$local_sessions/hyprland.desktop" "$system_sessions/hyprland.desktop"
  sudo chown "$user:$user" "$local_sessions/hyprland-nix.desktop" "$local_sessions/hyprland.desktop"

  sudo tee "$sddm_dropin" >/dev/null <<'EOF'
[Wayland]
SessionDir=/usr/local/share/wayland-sessions,/usr/share/wayland-sessions
EOF

  ok "session — $trampoline + SDDM SessionDir (updatehome refreshes the wrapper, not the .desktop)"
}

dnf_can_see_steam() {
  dnf -q list steam >/dev/null 2>&1
}

step_steam() {
  runmsg "steam — Fedora Asahi wrapper (muvm + FEX), not Nixpkgs Steam"

  if ! rpm -q steam >/dev/null 2>&1; then
    if ! dnf_can_see_steam; then
      warn "steam is not in the enabled repos — installing asahi-repos"
      sudo dnf install -y asahi-repos \
        || die "asahi-repos is missing; this host needs Fedora Asahi Remix repos"
    fi
    sudo dnf install -y steam
  fi

  [[ -x /usr/bin/steam ]] || die "/usr/bin/steam is missing after dnf install steam"

  local kb
  kb=$(awk '/^MemTotal:/ { print $2; exit }' /proc/meminfo 2>/dev/null || echo 0)
  if [[ $kb =~ ^[0-9]+$ ]] && (( kb < 16 * 1024 * 1024 )); then
    warn "this machine reports $((kb / 1024)) MiB RAM; Steam + FEX + muvm wants ~16G"
    warn "if games OOM: sudo /usr/libexec/fedora-asahi-remix-scripts/setup-swap.sh --recreate 16G"
  fi

  ok "steam — /usr/bin/steam  (launch with steam / teonix-steam after updatehome)"
}

run_step() {
  local step=$1
  if [[ ${FORCE:-0} != 1 ]] && "probe_${step}"; then
    skip "$step"
    return 0
  fi
  CURRENT_STEP=$step
  "step_${step}"
  CURRENT_STEP=""
}

usage() {
  cat <<EOF
${SELF} v${VERSION} — Nix + teonix desktop on Asahi Fedora

  ${CURL_CMD}

Fedora does not include Nix. This script installs it, clones teonix, points
/run/opengl-driver at Nix Mesa, unlocks GNOME Keyring at login, and switches
Home Manager to #${FLAKE_ATTR}. Re-run after any failure.

  … all              every pending desktop step (default — not steam)
  … <step>           one named step (nix git repo identity switch gpu
                     keyring session steam)
  … status           checklist
  … help

Environment:
  TEONIX_USER=…   Home Manager user (default \$USER — not hardcoded teodor)
  TEONIX_REPO=…   git remote (default ${TEONIX_REPO})
  TEONIX_DIR=…    checkout (default \$HOME/teonix)
  FORCE=1         redo steps that look finished
EOF
}

cmd_status() {
  local step
  say "${SELF} v${VERSION}"
  say "  user ${TEONIX_USER:-${USER:-$(id -un)}}"
  say "  dir  $TEONIX_DIR"
  say ""
  printf '%-10s %s\n' STEP STATE
  for step in "${STEPS[@]}"; do
    if "probe_${step}" 2>/dev/null; then
      printf '%-10s %s\n' "$step" done
    else
      printf '%-10s %s\n' "$step" pending
    fi
  done
  for step in "${EXTRA_STEPS[@]}"; do
    if "probe_${step}" 2>/dev/null; then
      printf '%-10s %s\n' "$step" "done (opt-in)"
    else
      printf '%-10s %s\n' "$step" "pending — fedora.sh $step"
    fi
  done
}

main() {
  [[ $(id -u) -ne 0 ]] || die "run as your normal user, not root — the Nix installer sudoes itself"

  case ${1:-all} in
    help | -h | --help) usage; return 0 ;;
    status) cmd_status; return 0 ;;
    all)
      local step
      for step in "${STEPS[@]}"; do
        run_step "$step"
      done
      ;;
    *)
      known_step "$1" || die "unknown command: $1 (try: help)"
      run_step "$1"
      ;;
  esac

  say ""
  ok "${SELF} v${VERSION} finished"
  if [[ ${1:-all} == steam ]]; then
    say "launch: steam   (or teonix-steam — after updatehome)"
  else
    say "log out and pick Hyprland (Nix) at the greeter"
    say "later updates: updatehome   (from a Nix-enabled shell)"
    say "Steam (opt-in): bash $TEONIX_DIR/hosts/applenix/fedora.sh steam"
  fi
}

main "$@"
