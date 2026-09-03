#!/usr/bin/env bash
# applenix USB installer — modular, idempotent. Safe to re-run after any failure.
# Run as root from the Asahi NixOS installer.
set -euo pipefail

readonly SCRIPT_VERSION=3
readonly SCRIPT_PATH="${BASH_SOURCE[0]}"
readonly SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"

REPO_URL="${TEONIX_REPO:-https://github.com/teoscloud/teonix.git}"
FLAKE_DIR="${TEONIX_DIR:-/mnt/home/teodor/teonix}"
NVME="${TEONIX_DISK:-/dev/nvme0n1}"
APPLE_SILICON_PIN="${APPLE_SILICON_PIN:-release-2026-07-30}"
STATE_DIR="${TEONIX_STATE_DIR:-/mnt/.teonix-bootstrap}"

readonly STEPS=(
  preflight
  mount-root
  mount-esp
  git
  clone
  patch
  hw-config
  firmware
  swap
  chown
  install
)

die() { echo "error: $*" >&2; exit 1; }

log() { echo "== $*"; }

step_ok() { echo "[ok]   $*"; }
step_skip() { echo "[skip] $*"; }
step_run() { echo "[run]  $*"; }

need_root() { [[ $(id -u) -eq 0 ]] || die "run as root (sudo su)"; }

auto_yes() { [[ ${YES:-}${NONINTERACTIVE:-} == *1* ]]; }

confirm() {
  local q=$1
  auto_yes && return 0
  read -r -p "$q [type YES]: " a
  [[ $a == YES ]] || die "aborted"
}

state_file() {
  mkdir -p "$STATE_DIR"
  echo "$STATE_DIR/completed"
}

state_mark() {
  local step=$1
  grep -qxF "$step" "$(state_file)" 2>/dev/null || echo "$step" >>"$(state_file)"
}

state_clear() {
  local step=$1
  [[ -f "$(state_file)" ]] || return 0
  local tmp
  tmp=$(mktemp)
  grep -vxF "$step" "$(state_file)" >"$tmp" || true
  mv "$tmp" "$(state_file)"
}

state_done() {
  local step=$1
  [[ -f "$(state_file)" ]] && grep -qxF "$step" "$(state_file)"
}

should_run() {
  local step=$1 check_fn=$2
  if [[ ${FORCE:-} == 1 ]]; then
    return 0
  fi
  "$check_fn" && return 1
  return 0
}

esp_dev() {
  local uuid
  uuid=$(tr -d '\0' < /proc/device-tree/chosen/asahi,efi-system-partition 2>/dev/null || true)
  [[ -n $uuid ]] || die "no asahi,efi-system-partition in device-tree (not an Asahi installer?)"
  echo "/dev/disk/by-partuuid/$uuid"
}

reread_pt() {
  partprobe "$NVME" 2>/dev/null || blockdev --rereadpt "$NVME" 2>/dev/null || true
  udevadm settle 2>/dev/null || sleep 1
}

find_root_part() {
  local n
  n=$(sgdisk -p "$NVME" 2>/dev/null | awk '/[[:space:]]8300[[:space:]]/ {print $1}' | tail -n1)
  if [[ -n $n ]]; then
    echo "${NVME}p${n}"
    return 0
  fi
  lsblk -npo NAME,PARTTYPE "$NVME" 2>/dev/null \
    | awk 'tolower($2) ~ /0fc63daf-8483-4772-8e79-3d69d8477de4/ {print $1}' \
    | tail -n1
}

require_mnt() {
  findmnt /mnt >/dev/null 2>&1 || die "/mnt is not mounted — run: $SCRIPT_PATH mount-root"
}

require_flake() {
  require_mnt
  [[ -d $FLAKE_DIR/.git || -f $FLAKE_DIR/flake.nix ]] \
    || die "flake missing at $FLAKE_DIR — run: $SCRIPT_PATH clone"
}

# --- live checks (source of truth; state file is secondary) ---

check_preflight() {
  ping -c1 -W3 cache.nixos.org >/dev/null 2>&1 || ping -c1 -W3 github.com >/dev/null 2>&1
}

check_mount_root() {
  findmnt /mnt >/dev/null 2>&1
}

check_mount_esp() {
  findmnt /mnt/boot >/dev/null 2>&1
}

check_git() {
  command -v git >/dev/null 2>&1
}

check_clone() {
  [[ -d $FLAKE_DIR/.git ]]
}

check_patch() {
  [[ -d $FLAKE_DIR/.git || -f $FLAKE_DIR/flake.nix ]] || return 1
  grep -q "nixos-apple-silicon/${APPLE_SILICON_PIN}" "$FLAKE_DIR/flake.nix" \
    && grep -q 'applenix-bootstrap' "$FLAKE_DIR/flake.nix" \
    && [[ -f $FLAKE_DIR/hosts/applenix/asahi.nix ]] \
    && [[ -f $FLAKE_DIR/hosts/applenix/bootstrap.nix ]]
}

check_hw_config() {
  [[ -f $FLAKE_DIR/hosts/applenix/hardware-configuration.nix ]]
}

check_firmware() {
  [[ -f $FLAKE_DIR/hosts/applenix/firmware/firmware.cpio ]]
}

check_swap() {
  grep -q '/mnt/swapfile' /proc/swaps 2>/dev/null
}

check_chown() {
  [[ -d /mnt/home/teodor ]] && [[ $(stat -c '%u' /mnt/home/teodor 2>/dev/null || echo '') == 1000 ]]
}

check_install() {
  [[ -L /mnt/nix/var/nix/profiles/system || -e /mnt/nix/var/nix/profiles/system ]]
}

# --- embedded fallbacks when only bootstrap.sh was curled to /tmp ---

embed_asahi_nix() {
  cat <<'EOF'
{ apple-silicon, lib, ... }:

{
  imports = [ apple-silicon.nixosModules.apple-silicon-support ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = false;

  networking.networkmanager.wifi.backend = lib.mkDefault "iwd";
  networking.wireless.iwd.enable = lib.mkDefault true;

  hardware.asahi =
    let
      localFw = ./firmware/firmware.cpio;
      hasLocalFw = builtins.pathExists localFw;
    in
    {
      enable = true;
      setupAsahiSound = true;
      extractPeripheralFirmware = hasLocalFw;
      peripheralFirmwareDirectory = if hasLocalFw then ./firmware else null;
      overlay = import "${apple-silicon}/apple-silicon-support/packages/overlay.nix";
    };

  services.power-profiles-daemon.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="macsmc-battery", ATTR{charge_control_end_threshold}="80"
  '';

  boot.kernelParams = [ "appledrm.show_notch=1" ];
}
EOF
}

embed_bootstrap_nix() {
  cat <<'EOF'
{ pkgs, username, ... }:

{
  networking.hostName = "applenix";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.wireless.iwd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = false;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nixpkgs.config.allowUnfree = true;

  users.mutableUsers = true;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    initialPassword = "teodor";
  };
  users.users.root.initialPassword = "teodor";

  environment.systemPackages = with pkgs; [ git vim tmux curl ];
  zramSwap.enable = true;

  services.getty.helpLine = ''

    applenix bootstrap is up. Login: teodor / teodor  (change this now)
    Then:
      cd ~/teonix
      sudo nixos-rebuild switch --flake path:.#applenix --impure
  '';

  system.stateVersion = "24.05";
}
EOF
}

install_host_file() {
  local name=$1
  local dest="$FLAKE_DIR/hosts/applenix/$name"
  mkdir -p "$(dirname "$dest")"
  if [[ -f $SCRIPT_DIR/$name ]]; then
    cp "$SCRIPT_DIR/$name" "$dest"
  else
    case $name in
      asahi.nix) embed_asahi_nix >"$dest" ;;
      bootstrap.nix) embed_bootstrap_nix >"$dest" ;;
      *) die "no bundled copy of $name" ;;
    esac
  fi
}

# --- step implementations ---

step_preflight() {
  need_root
  command -v sgdisk >/dev/null || die "sgdisk missing (use nixos-apple-silicon installer ISO)"

  if ! ping -c1 -W3 github.com >/dev/null 2>&1 && ! ping -c1 -W3 cache.nixos.org >/dev/null 2>&1; then
    cat <<'EOF'
No network. In this installer:

  iwctl
  [iwd]# station wlan0 scan
  [iwd]# station wlan0 connect YOUR_SSID
  [iwd]# exit

Then: systemctl restart systemd-timesyncd
Re-run: bootstrap.sh preflight
EOF
    exit 1
  fi

  systemctl restart systemd-timesyncd || true
  step_ok "preflight (network, root, tools)"
}

step_mount_root() {
  need_root

  if findmnt /mnt >/dev/null 2>&1; then
    step_skip "mount-root — already mounted as $(findmnt -n -o SOURCE /mnt)"
    return 0
  fi

  echo
  sgdisk "$NVME" -p || true
  reread_pt

  local root
  root=$(find_root_part)

  if [[ -z ${root:-} || ! -b $root ]]; then
    [[ ${CREATE_PARTITION:-} == 1 ]] || confirm "Create NixOS root partition (8300) on $NVME?"
    sgdisk "$NVME" -n 0:0:0 -t 0:8300 -c 0:nixos -s
    reread_pt
    root=$(find_root_part)
    [[ -n ${root:-} && -b $root ]] \
      || die "no 8300 partition after create — check: sgdisk $NVME -p"
  fi

  local fstype
  fstype=$(blkid -o value -s TYPE "$root" 2>/dev/null || true)

  if [[ $fstype == ext4 ]]; then
    step_skip "mount-root — $root already ext4, not formatting"
  elif [[ -n $fstype && ${FORMAT:-} != 1 ]]; then
    die "$root has filesystem type '$fstype' — mount manually or set FORMAT=1 to overwrite"
  else
    confirm "Format $root as ext4 (erases that partition only)?"
    mkfs.ext4 -L nixos "$root"
  fi

  mount "$root" /mnt
  step_ok "mount-root — $(findmnt -n -o SOURCE /mnt) on /mnt"
}

step_mount_esp() {
  need_root
  require_mnt

  if findmnt /mnt/boot >/dev/null 2>&1; then
    step_skip "mount-esp — already $(findmnt -n -o SOURCE /mnt/boot) on /mnt/boot"
    return 0
  fi

  mkdir -p /mnt/boot
  mount "$(esp_dev)" /mnt/boot
  step_ok "mount-esp — $(findmnt -n -o SOURCE /mnt/boot) on /mnt/boot"
}

step_git() {
  if command -v git >/dev/null 2>&1; then
    step_skip "git — $(command -v git)"
    return 0
  fi

  echo "installer has no git; pulling from nixpkgs…"
  nix-env -iA nixos.git 2>/dev/null || nix-env -iA nixpkgs.git 2>/dev/null || true
  command -v git >/dev/null || nix-shell -p git --run "true"
  step_ok "git — $(command -v git || echo nix-shell)"
}

step_clone() {
  require_mnt
  step_git

  mkdir -p "$(dirname "$FLAKE_DIR")"

  if [[ -d $FLAKE_DIR/.git ]]; then
    step_skip "clone — repo at $FLAKE_DIR"
    if [[ ${PULL:-} == 1 ]] && command -v git >/dev/null; then
      echo "pulling latest…"
      git -C "$FLAKE_DIR" pull --ff-only || echo "warn: git pull failed (offline or diverged)"
    fi
    return 0
  fi

  echo "cloning $REPO_URL -> $FLAKE_DIR"
  if command -v git >/dev/null; then
    git clone "$REPO_URL" "$FLAKE_DIR"
  else
    nix-shell -p git --run "git clone '$REPO_URL' '$FLAKE_DIR'"
  fi
  step_ok "clone — $FLAKE_DIR"
}

step_patch() {
  require_flake

  echo "patching Asahi pin + host modules in $FLAKE_DIR"
  install_host_file asahi.nix
  install_host_file bootstrap.nix

  sed -i \
    "s|github:nix-community/nixos-apple-silicon/release-[0-9][0-9-]*|github:nix-community/nixos-apple-silicon/${APPLE_SILICON_PIN}|g" \
    "$FLAKE_DIR/flake.nix"

  grep -q "nixos-apple-silicon/${APPLE_SILICON_PIN}" "$FLAKE_DIR/flake.nix" \
    || die "flake.nix still missing apple-silicon ${APPLE_SILICON_PIN} — repo too old?"

  if ! grep -q 'applenix-bootstrap' "$FLAKE_DIR/flake.nix"; then
    die "flake.nix missing #applenix-bootstrap — on nixbox: git push, then here: PULL=1 bash $SCRIPT_PATH clone patch"
  fi

  step_ok "patch — apple-silicon ${APPLE_SILICON_PIN}, asahi.nix, bootstrap.nix"
}

step_hw_config() {
  require_flake

  local out="$FLAKE_DIR/hosts/applenix/hardware-configuration.nix"
  nixos-generate-config --root /mnt --show-hardware-config >"$out"
  sed -i '/extractPeripheralFirmware/d' "$out"
  step_ok "hw-config — wrote $out"
}

step_firmware() {
  require_flake
  require_mnt
  findmnt /mnt/boot >/dev/null 2>&1 || die "ESP not on /mnt/boot — run: $SCRIPT_PATH mount-esp"

  local dest="$FLAKE_DIR/hosts/applenix/firmware"
  mkdir -p "$dest"

  if [[ -f $dest/firmware.cpio && ${FORCE:-} != 1 ]]; then
    step_skip "firmware — $dest/firmware.cpio already present"
    return 0
  fi

  if [[ -f /mnt/boot/vendorfw/firmware.cpio ]]; then
    cp -a /mnt/boot/vendorfw/. "$dest/"
  elif [[ -d /mnt/boot/asahi ]]; then
    cp -a /mnt/boot/asahi/. "$dest/"
  else
    echo "warn: no ESP firmware at /mnt/boot — later rebuilds need --impure"
    return 0
  fi

  step_ok "firmware — copied ESP firmware to $dest"
}

step_swap() {
  require_mnt

  if grep -q '/mnt/swapfile' /proc/swaps 2>/dev/null; then
    step_skip "swap — /mnt/swapfile already active"
    return 0
  fi

  echo "adding 8G swap on /mnt for the Asahi kernel compile…"
  if [[ ! -f /mnt/swapfile ]]; then
    if ! fallocate -l 8G /mnt/swapfile 2>/dev/null; then
      dd if=/dev/zero of=/mnt/swapfile bs=1M count=8192 status=progress
    fi
    chmod 600 /mnt/swapfile
    mkswap /mnt/swapfile
  fi
  swapon /mnt/swapfile
  step_ok "swap — /mnt/swapfile"
}

step_chown() {
  require_mnt
  chown -R 1000:1000 /mnt/home/teodor 2>/dev/null || true
  step_ok "chown — /mnt/home/teodor -> teodor (1000)"
}

step_install() {
  require_flake

  if check_install && [[ ${FORCE:-} != 1 ]]; then
    step_skip "install — NixOS system profile already exists under /mnt/nix (FORCE=1 to reinstall)"
    return 0
  fi

  if [[ ${SKIP_INSTALL:-} == 1 ]]; then
    step_skip "install — SKIP_INSTALL=1"
    return 0
  fi

  echo "installing #applenix-bootstrap (this takes a while)…"
  nixos-install \
    --root /mnt \
    --no-channel-copy \
    --no-root-password \
    --impure \
    --flake "$FLAKE_DIR#applenix-bootstrap"

  step_ok "install — #applenix-bootstrap"
}

# --- dispatcher ---

run_step() {
  local step=$1
  local fn="step_${step//-/_}"
  [[ $(type -t "$fn") == function ]] || die "unknown step: $step"

  if should_run "$step" "check_${step//-/_}"; then
    step_run "$step"
    "$fn"
    state_mark "$step"
  else
    step_skip "$step — looks complete (FORCE=1 to redo)"
  fi
}

cmd_status() {
  local step detail
  echo "applenix bootstrap v${SCRIPT_VERSION}"
  echo "  script:  $SCRIPT_PATH"
  echo "  flake:   $FLAKE_DIR"
  echo "  disk:    $NVME"
  echo "  state:   $(state_file 2>/dev/null || echo '(no /mnt yet)')"
  echo
  printf "%-12s %-8s %s\n" "STEP" "STATUS" "DETAIL"
  for step in "${STEPS[@]}"; do
    detail=""
    case $step in
      mount-root)
        findmnt /mnt >/dev/null 2>&1 && detail="$(findmnt -n -o SOURCE /mnt) -> /mnt" || detail="not mounted"
        ;;
      mount-esp)
        findmnt /mnt/boot >/dev/null 2>&1 && detail="$(findmnt -n -o SOURCE /mnt/boot) -> /mnt/boot" || detail="not mounted"
        ;;
      clone)
        [[ -d $FLAKE_DIR/.git ]] && detail="$FLAKE_DIR" || detail="missing"
        ;;
      patch)
        if [[ -f $FLAKE_DIR/flake.nix ]]; then
          detail=$(grep -o 'release-[0-9-]*' "$FLAKE_DIR/flake.nix" | head -n1 || echo "?")
        else
          detail="no flake"
        fi
        ;;
      firmware)
        [[ -f $FLAKE_DIR/hosts/applenix/firmware/firmware.cpio ]] && detail="present" || detail="missing"
        ;;
      install)
        check_install && detail="system profile exists" || detail="not installed"
        ;;
    esac
    if "check_${step//-/_}" 2>/dev/null; then
      printf "%-12s %-8s %s\n" "$step" "done" "$detail"
    elif state_done "$step"; then
      printf "%-12s %-8s %s\n" "$step" "stale?" "$detail"
    else
      printf "%-12s %-8s %s\n" "$step" "pending" "$detail"
    fi
  done
}

cmd_list() {
  printf '%s\n' "${STEPS[@]}"
}

usage() {
  cat <<EOF
applenix bootstrap v${SCRIPT_VERSION} — modular USB installer

Usage:
  $(basename "$SCRIPT_PATH")              Run all pending steps (default)
  $(basename "$SCRIPT_PATH") all          Same as above
  $(basename "$SCRIPT_PATH") status       Show live step checklist
  $(basename "$SCRIPT_PATH") list         List step names
  $(basename "$SCRIPT_PATH") reset STEP   Forget STEP in state file (does not undo disk)
  $(basename "$SCRIPT_PATH") STEP [...]   Run specific step(s) only

Steps (in order):
  preflight mount-root mount-esp git clone patch hw-config firmware swap chown install

Environment:
  YES=1 NONINTERACTIVE=1   Skip confirmation prompts
  FORCE=1                  Redo steps even when they look complete
  FORMAT=1                 Allow mkfs on a non-ext4 partition
  CREATE_PARTITION=1       Create 8300 slice when missing (still asks unless YES=1)
  SKIP_INSTALL=1           Prepare /mnt only, skip nixos-install
  PULL=1                   git pull when clone already exists
  TEONIX_REPO TEONIX_DIR TEONIX_DISK APPLE_SILICON_PIN

After install:
  reboot
  login teodor / teodor, then:
    cd ~/teonix && sudo nixos-rebuild switch --flake path:.#applenix --impure
EOF
}

main() {
  local cmd=${1:-all}

  case $cmd in
    -h | --help | help)
      usage
      ;;
    status)
      cmd_status
      ;;
    list)
      cmd_list
      ;;
    reset)
      [[ -n ${2:-} ]] || die "usage: $(basename "$SCRIPT_PATH") reset STEP"
      state_clear "$2"
      echo "cleared state for: $2"
      ;;
    all | "")
      log "applenix bootstrap v${SCRIPT_VERSION}"
      for step in "${STEPS[@]}"; do
        run_step "$step"
      done
      echo
      echo "done. reboot, pick NixOS, login teodor / teodor"
      echo "then:  cd ~/teonix && sudo nixos-rebuild switch --flake path:.#applenix --impure"
      echo "then:  passwd"
      ;;
    *)
      need_root
      for step in "$@"; do
        run_step "$step"
      done
      ;;
  esac
}

main "$@"
