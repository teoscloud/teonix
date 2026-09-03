#!/usr/bin/env bash
# Run as root from the Asahi NixOS USB installer.
# Re-run is safe if /mnt is already mounted (skips partition/format).
set -euo pipefail

REPO_URL="${TEONIX_REPO:-https://github.com/teoscloud/teonix.git}"
FLAKE_DIR="${TEONIX_DIR:-/mnt/home/teodor/teonix}"
NVME="${TEONIX_DISK:-/dev/nvme0n1}"

die() { echo "error: $*" >&2; exit 1; }
need_root() { [[ $(id -u) -eq 0 ]] || die "run as root (sudo su)"; }

confirm() {
  local q=$1
  read -r -p "$q [type YES]: " a
  [[ $a == YES ]] || die "aborted"
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

ensure_git() {
  command -v git >/dev/null && return 0
  echo "installer has no git; pulling it from nixpkgs…"
  nix-env -iA nixos.git 2>/dev/null || nix-env -iA nixpkgs.git 2>/dev/null || true
  command -v git >/dev/null && return 0
  nix-shell -p git --run "true"
}

git_clone() {
  if command -v git >/dev/null; then
    git clone "$REPO_URL" "$FLAKE_DIR"
  else
    nix-shell -p git --run "git clone '$REPO_URL' '$FLAKE_DIR'"
  fi
}

copy_firmware() {
  local dest="$FLAKE_DIR/hosts/applenix/firmware"
  mkdir -p "$dest"
  if [[ -f /mnt/boot/vendorfw/firmware.cpio ]]; then
    cp -a /mnt/boot/vendorfw/. "$dest/"
  elif [[ -d /mnt/boot/asahi ]]; then
    cp -a /mnt/boot/asahi/. "$dest/"
  else
    echo "warn: no ESP firmware found; later rebuilds need --impure"
    return 0
  fi
  echo "copied peripheral firmware -> $dest"
}

write_hw_config() {
  local out="$FLAKE_DIR/hosts/applenix/hardware-configuration.nix"
  nixos-generate-config --root /mnt --show-hardware-config > "$out"
  sed -i '/extractPeripheralFirmware/d' "$out"
  echo "wrote $out"
}

ensure_swap() {
  if grep -q '/mnt/swapfile' /proc/swaps 2>/dev/null; then
    echo "swapfile already on"
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
}

# Overwrite Asahi bits so a stale GitHub clone still builds on nixpkgs 26.11.
apply_asahi_fix() {
  echo "applying Asahi 2026-07-30 + linux-config fix in $FLAKE_DIR"

  cat > "$FLAKE_DIR/hosts/applenix/asahi.nix" <<'EOF'
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
      peripheralFirmwareDirectory = lib.mkIf hasLocalFw ./firmware;
      overlay = final: prev:
        let
          base = import "${apple-silicon}/apple-silicon-support/packages/overlay.nix" final prev;
        in
        base
        // {
          linux-asahi = final.callPackage "${apple-silicon}/apple-silicon-support/packages/linux-asahi" {
            ignoreConfigErrors = true;
          };
        };
    };

  services.power-profiles-daemon.enable = true;

  services.udev.extraRules = ''
    SUBSYSTEM=="power_supply", KERNEL=="macsmc-battery", ATTR{charge_control_end_threshold}="80"
  '';

  boot.kernelParams = [ "appledrm.show_notch=1" ];
}
EOF

  cat > "$FLAKE_DIR/hosts/applenix/bootstrap.nix" <<'EOF'
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

  python3 - "$FLAKE_DIR/flake.nix" <<'PY'
from pathlib import Path
import re
import sys

p = Path(sys.argv[1])
t = p.read_text()
t2, n = re.subn(
    r"nixos-apple-silicon/release-[0-9-]+",
    "nixos-apple-silicon/release-2026-07-30",
    t,
)
if n:
    print(f"flake: apple-silicon -> release-2026-07-30 ({n})")
t = t2
if "applenix-bootstrap" not in t:
    old = "\n    };\n\n    homeConfigurations = {"
    new = """
      applenix-bootstrap = nixos-unstable.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = mkCommonSpecialArgs "aarch64-linux" // { hostname = applenix_hostname; };
        modules = [
          ./hosts/applenix/asahi.nix
          ./hosts/applenix/hardware-configuration.nix
          ./hosts/applenix/bootstrap.nix
        ];
      };
    };

    homeConfigurations = {"""
    if old not in t:
        sys.exit("could not insert applenix-bootstrap into flake.nix")
    t = t.replace(old, new, 1)
    print("flake: added #applenix-bootstrap")
p.write_text(t)
PY
}

echo "== applenix bootstrap =="
need_root
command -v sgdisk >/dev/null || die "sgdisk missing (wrong ISO? use nixos-apple-silicon installer)"

if ! ping -c1 -W3 github.com >/dev/null 2>&1 && ! ping -c1 -W3 cache.nixos.org >/dev/null 2>&1; then
  cat <<'EOF'
No network. In this installer:

  iwctl
  [iwd]# station wlan0 scan
  [iwd]# station wlan0 connect YOUR_SSID
  [iwd]# exit

Then: systemctl restart systemd-timesyncd
Re-run this script.
EOF
  exit 1
fi

systemctl restart systemd-timesyncd || true

if ! findmnt /mnt >/dev/null 2>&1; then
  echo
  echo "Nothing is mounted on /mnt."
  sgdisk "$NVME" -p || true
  reread_pt
  ROOT=$(find_root_part)

  if [[ -n ${ROOT:-} && -b $ROOT ]]; then
    echo "Found existing Linux partition $ROOT."
    confirm "Format $ROOT as ext4 (erases that partition only) and mount /mnt?"
  else
    confirm "Create and format the NixOS root partition on $NVME?"
    sgdisk "$NVME" -n 0:0:0 -t 0:8300 -c 0:nixos -s
    reread_pt
    ROOT=$(find_root_part)
    [[ -n ${ROOT:-} && -b $ROOT ]] || die "no 8300 partition — use sgdisk -p and mount the Linux slice on /mnt, then re-run"
    confirm "Format $ROOT as ext4 and mount /mnt?"
  fi

  echo "formatting $ROOT"
  mkfs.ext4 -L nixos "$ROOT"
  mount "$ROOT" /mnt
fi

mkdir -p /mnt/boot
if ! findmnt /mnt/boot >/dev/null 2>&1; then
  mount "$(esp_dev)" /mnt/boot
fi

echo "root: $(findmnt -n -o SOURCE /mnt)"
echo "esp:  $(findmnt -n -o SOURCE /mnt/boot)"

ensure_git
mkdir -p /mnt/home/teodor
if [[ ! -d $FLAKE_DIR/.git ]]; then
  echo "cloning $REPO_URL -> $FLAKE_DIR"
  git_clone
else
  echo "flake already at $FLAKE_DIR"
fi

write_hw_config
copy_firmware
apply_asahi_fix
ensure_swap
chown -R 1000:1000 /mnt/home/teodor || true

echo
echo "installing #applenix-bootstrap…"
nixos-install \
  --root /mnt \
  --no-channel-copy \
  --no-root-password \
  --impure \
  --flake "$FLAKE_DIR#applenix-bootstrap"

echo
echo "done. reboot, pick NixOS, login teodor / teodor"
echo "then:  cd ~/teonix && sudo nixos-rebuild switch --flake path:.#applenix --impure"
echo "then:  passwd"
