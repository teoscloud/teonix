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

readonly VERSION=2
readonly SELF="applenix-fedora"
readonly CURL_CMD="curl -fsSL https://raw.githubusercontent.com/teoscloud/teonix/main/hosts/applenix/fedora.sh | bash"
readonly FLAKE_ATTR=applenix-fedora

TEONIX_REPO="${TEONIX_REPO:-https://github.com/teoscloud/teonix.git}"
TEONIX_DIR="${TEONIX_DIR:-$HOME/teonix}"

readonly STEPS=(nix git repo identity switch session)

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
probe_session() {
  [[ -f $HOME/.local/share/wayland-sessions/hyprland-nix.desktop ]] \
    || [[ -f /usr/share/wayland-sessions/hyprland-nix.desktop ]]
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

step_session() {
  local src="$HOME/.local/share/wayland-sessions/hyprland-nix.desktop"
  local dest=/usr/share/wayland-sessions/hyprland-nix.desktop

  if [[ ! -f $src ]]; then
    warn "no $src yet — home-manager should have written it; skip greeter copy"
    return 0
  fi

  if [[ -f $dest ]] && cmp -s "$src" "$dest"; then
    skip "session — greeter already has Hyprland (Nix)"
    return 0
  fi

  runmsg "session — copy desktop file for GDM (it ignores ~/.local/share/wayland-sessions)"
  sudo mkdir -p /usr/share/wayland-sessions
  sudo cp "$src" "$dest"
  ok "session — $dest"
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

Fedora does not include Nix. This script installs it, clones teonix, and
switches Home Manager to #${FLAKE_ATTR}. Re-run after any failure.

  … all       every pending step (default)
  … status    checklist
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
    *) die "unknown command: $1 (try: help)" ;;
  esac

  say ""
  ok "${SELF} v${VERSION} finished"
  say "log out and pick Hyprland (Nix) at the greeter"
  say "later updates: updatehome   (from a Nix-enabled shell)"
}

main "$@"
