# applenix — Asahi installer → teonix flake

Two stages on purpose:

1. **`#applenix-bootstrap`** — console-only, installs from the USB in a few minutes.
2. **`#applenix`** — full Hyprland rice, switched after the first reboot (long download).

Do **not** run `nixos-install` against `#applenix` from the USB. That closure is huge and the installer will often OOM while compiling the Asahi kernel.

Default login after bootstrap: **`teodor` / `teodor`**. Change it on first boot.

---

## 0. Before the USB (skip if you already boot the installer)

You need:

- Apple Silicon Mac, macOS 12.3+, admin account, backups
- USB stick ≥512 MB
- [nixos-apple-silicon installer ISO](https://github.com/nix-community/nixos-apple-silicon/releases) — prefer a release that matches this flake’s pin (`apple-silicon` input = `release-2025-11-18`)
- Free space for NixOS (Asahi will ask; leave macOS at least ~20 GB smaller)

### macOS → UEFI (Terminal.app)

```bash
curl https://alx.sh | sh
```

- Resize macOS to make room (`r`)
- Install into free space (`f`) → **UEFI environment only** (not Fedora)
- Name it **NixOS**
- Shut down, hold power → boot picker → **NixOS**
- Recovery: set a custom boot object, **permissive** security, reboot into U-Boot
- Write the ISO with `dd` to the **disk**, not a partition. No Etcher/Unetbootin.

```bash
# from another Linux machine, disk name will differ
sudo dd if=nixos-asahi-installer.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Hold power, pick **NixOS**, U-Boot should autoboot USB. If it jumps to an old install:

```
# at U-Boot prompt
eficonfig          # move "usb 0" to the top, Save, Quit
boot
```

---

## 1. Installer prompt

You are at `nixos login:` on the USB.

```bash
sudo su
setfont ter-v32n          # optional, bigger font
```

### Wi‑Fi (almost always required)

```bash
iwctl
[iwd]# station wlan0 scan
[iwd]# station wlan0 connect YOUR_SSID
[iwd]# station wlan0 show
[iwd]# exit
systemctl restart systemd-timesyncd
ping -c2 cache.nixos.org
```

Ethernet works too if you have a dongle.

---

## 2. One-shot bootstrap

Still as root:

```bash
curl -fsSL https://raw.githubusercontent.com/teoscloud/teonix/main/hosts/applenix/bootstrap.sh -o /tmp/bootstrap.sh
bash /tmp/bootstrap.sh
```

The script will:

1. Refuse to run without network
2. Ask you to type `YES`, then create **one** ext4 partition in the leftover free space on `/dev/nvme0n1` (does **not** touch iBoot, macOS, or Recovery)
3. Mount root + the Asahi ESP (`/boot`)
4. Clone this repo to `/mnt/home/teodor/teonix`
5. Write a real `hosts/applenix/hardware-configuration.nix` (UUIDs from this machine)
6. Copy ESP firmware into `hosts/applenix/firmware/` (gitignored)
7. `nixos-install --flake …#applenix-bootstrap --impure`

If the repo is private, clone it yourself first (token or `scp` from nixbox), then:

```bash
TEONIX_DIR=/mnt/home/teodor/teonix bash /tmp/bootstrap.sh
```

When it finishes:

```bash
reboot
```

Unplug the USB. First boot is a TTY.

---

## 3. Manual path (if you do not want the script)

**Danger:** do not use an automated partitioner. Damaging GPT / `iBootSystemContainer` / `RecoveryOSContainer` bricks the Mac without another computer + DFU.

```bash
sgdisk /dev/nvme0n1 -p
sgdisk /dev/nvme0n1 -n 0:0 -t 0:8300 -s
sgdisk /dev/nvme0n1 -p          # note the new 8300 partition, e.g. nvme0n1p5

mkfs.ext4 -L nixos /dev/nvme0n1p5
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-partuuid/$(cat /proc/device-tree/chosen/asahi,efi-system-partition) /mnt/boot

mkdir -p /mnt/home/teodor
git clone https://github.com/teoscloud/teonix.git /mnt/home/teodor/teonix

nixos-generate-config --root /mnt --show-hardware-config \
  > /mnt/home/teodor/teonix/hosts/applenix/hardware-configuration.nix
sed -i '/extractPeripheralFirmware/d' \
  /mnt/home/teodor/teonix/hosts/applenix/hardware-configuration.nix

mkdir -p /mnt/home/teodor/teonix/hosts/applenix/firmware
cp -a /mnt/boot/vendorfw/. /mnt/home/teodor/teonix/hosts/applenix/firmware/ 2>/dev/null \
  || cp -a /mnt/boot/asahi/. /mnt/home/teodor/teonix/hosts/applenix/firmware/

chown -R 1000:1000 /mnt/home/teodor

nixos-install --root /mnt --no-channel-copy --no-root-password --impure \
  --flake /mnt/home/teodor/teonix#applenix-bootstrap

reboot
```

---

## 4. First boot → full flake

Login **`teodor` / `teodor`**.

```bash
passwd                          # change it now
cd ~/teonix
sudo nixos-rebuild switch --flake path:.#applenix --impure
```

Home Manager is nested in that switch. First time this will download a lot. Use `tmux` if you want it to survive a dropped SSH.

If GDM comes up, pick **Hyprland**.

```bash
sudo reboot
```

Then, from a terminal in the rice:

```bash
passwd
systemupdate                    # later updates; already includes --impure
```

### Why `--impure`?

Asahi peripheral firmware lives on the ESP (`/boot/asahi` or `vendorfw/`). Until `hosts/applenix/firmware/firmware.cpio` exists in the working tree (the bootstrap copies it; it is gitignored), Nix must read `/boot` at eval time.

---

## 5. Check

| What | How |
|------|-----|
| GPU | `glxinfo \| grep renderer` |
| Wi‑Fi | `nmcli` / `iwctl` |
| Audio | PipeWire, built-in speakers |
| Hyprland | GDM → Hyprland |
| Quickshell | bar on the built-in panel |
| hyprflow | `hfstatus` |

If the panel is not `eDP-1`:

- `home/hosts/applenix/dotfiles/config/hypr/hyprland.conf`
- `home/hosts/applenix/dotfiles/config/quickshell/Globals.qml` (`shellMonitor`)

then `updatehome`.

Commit the generated `hardware-configuration.nix` when you are happy (never commit `hosts/applenix/firmware/`).

---

## Rescue

USB again → U-Boot: stop autoboot → `bootmenu` → `usb 0`.

```bash
sudo su
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot
mount /dev/disk/by-partuuid/$(cat /proc/device-tree/chosen/asahi,efi-system-partition) /mnt/boot
nixos-install --root /mnt --no-channel-copy --no-root-password --impure \
  --flake /mnt/home/teodor/teonix#applenix-bootstrap
```

That only adds a generation. User data stays.

---

## Dual-boot macOS

Hold power at boot for the picker. The Asahi stub macOS partition stays for firmware updates (`curl https://alx.sh | sh` → rebuild vendor firmware, then rebuild NixOS).

---

## Files

| Path | Role |
|------|------|
| `hosts/applenix/bootstrap.nix` | Minimal NixOS (console, iwd, systemd-boot) |
| `hosts/applenix/bootstrap.sh` | Installer script |
| `hosts/applenix/asahi.nix` | Kernel, sound, bootloader, firmware |
| `hosts/applenix/hardware-configuration.nix` | **Overwrite on the Mac** — placeholder UUIDs only eval off-device |
| `hosts/applenix/firmware/` | Local ESP copy, gitignored |
| flake `#applenix-bootstrap` | First install |
| flake `#applenix` | Full rice |
