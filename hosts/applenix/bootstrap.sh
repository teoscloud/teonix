#!/usr/bin/env bash
# Run as root from the Asahi NixOS USB installer.
# Installs #applenix-bootstrap onto the internal NVMe, then you reboot
# and switch to #applenix. See hosts/applenix/INSTALL.md.
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

find_root_part() {
  # Newest Linux (8300) partition on the NVMe, excluding Apple containers.
  lsblk -npo NAME,PARTTYPE "$NVME" | awk 'tolower($2)=="0fc63daf-8483-4772-8e79-3d69d8477de4" {print $1}' | tail -n1
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
  # Placeholder-only flag; real machine must extract firmware from the ESP.
  sed -i '/extractPeripheralFirmware/d' "$out"
  echo "wrote $out"
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
  echo "This will ADD a Linux partition in the remaining free space on $NVME"
  echo "and format it ext4. It will NOT touch iBoot / macOS / Recovery."
  sgdisk "$NVME" -p || true
  confirm "Create and format the NixOS root partition on $NVME?"

  sgdisk "$NVME" -n 0:0 -t 0:8300 -s
  ROOT=$(find_root_part)
  [[ -n $ROOT ]] || die "could not find the new 8300 partition"
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

mkdir -p /mnt/home/teodor
if [[ ! -d $FLAKE_DIR/.git ]]; then
  echo "cloning $REPO_URL -> $FLAKE_DIR"
  git clone "$REPO_URL" "$FLAKE_DIR"
else
  echo "flake already at $FLAKE_DIR"
fi

write_hw_config
copy_firmware
chown -R 1000:1000 /mnt/home/teodor

echo
echo "installing #applenix-bootstrap (console only, a few minutes)…"
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
