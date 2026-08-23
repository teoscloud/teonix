# applenix: fresh Asahi + NixOS install

Apple Silicon MacBook (M1/M2) host for teonix. Follow the [nixos-apple-silicon UEFI standalone guide](https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/uefi-standalone.md) for background; this runbook is teonix-specific.

## Prerequisites

- Supported Apple Silicon Mac with macOS 12.3+, admin account, backups
- USB flash drive (≥512 MB) for the NixOS installer ISO
- Free disk space for NixOS + Asahi stub macOS partition
- Clone teonix to **`/home/teodor/teonix`** (same path as other hosts — zsh aliases depend on it)

## 1. macOS prep

1. Back up important data.
2. Free enough disk space for Linux (Asahi installer will guide sizing).
3. Keep macOS updated enough for the [Asahi installer](https://github.com/AsahiLinux/asahi-installer).

## 2. Asahi UEFI environment

1. Run the official **Asahi Linux installer** from macOS to create the stub macOS + UEFI boot chain.
2. **Do not** install Fedora as the reference OS if you are going straight to NixOS — stop after UEFI/m1n1 setup per the nixos-apple-silicon guide.
3. Build or download the **nixos-apple-silicon installer ISO** ([releases](https://github.com/nix-community/nixos-apple-silicon/releases)) and write it to USB with `dd`.

## 3. Boot installer & partition

1. Boot the NixOS installer ISO from the Asahi boot picker.
2. Partition the Linux slice (ext4 root + vfat `/boot`, swap optional).
3. Mount targets under `/mnt` as usual.

## 4. Generate hardware config

```bash
sudo nixos-generate-config --root /mnt
sudo cp /mnt/etc/nixos/hardware-configuration.nix /path/to/teonix/hosts/applenix/hardware-configuration.nix
```

Replace the placeholder UUIDs in the repo with the generated file, then commit.

Remove `hardware.asahi.extractPeripheralFirmware = false` from the generated hardware config (placeholder for off-device flake eval only).

## 5. First switch

From the installed system (or chroot with `/mnt`):

```bash
cd /home/teodor/teonix
nix flake update

sudo nixos-rebuild switch --flake /home/teodor/teonix#applenix --impure
home-manager switch --flake /home/teodor/teonix#applenix -b bak --impure
```

### Why `--impure`?

Asahi peripheral firmware normally lives under `/boot/asahi`. Until you vendor it into the flake (`hardware.asahi.peripheralFirmwareDirectory = ./firmware`), rebuilds need `--impure` so Nix can read `/boot/asahi`. See [nixos-apple-silicon#299](https://github.com/nix-community/nixos-apple-silicon/issues/299).

After vendoring firmware into `hosts/applenix/firmware/`, you can drop `--impure` from `systemupdate` / `updatehome`.

## 6. Reboot & verify

```bash
sudo reboot
```

Checklist:

| Item | Command / note |
|------|----------------|
| GPU | `glxinfo \| grep renderer` |
| Wi‑Fi / BT | `nmcli`, `bluetoothctl` |
| Audio | built-in speakers via PipeWire |
| Hyprland | GDM session picker → Hyprland |
| Quickshell | bar on built-in panel (`hyprctl monitors` → `Globals.shellMonitor`) |
| hyprflow | `hfstatus`, `hfrestore` |

If the built-in monitor name is not `eDP-1`, edit:

- `home/hosts/applenix/dotfiles/config/hypr/hyprland.conf` (`monitor = …`)
- `home/hosts/applenix/dotfiles/config/quickshell/Globals.qml` (`shellMonitor`)

Then `updatehome`.

## 7. Off-device eval (optional)

From any machine with Nix:

```bash
nix build .#nixosConfigurations.applenix.config.system.build.toplevel --system aarch64-linux
```

## Daily rebuilds

```bash
systemupdate   # full flake update + nixos + home (includes --impure)
updatehome     # home-manager only
```

Aliases are in `home/hosts/applenix/modules/zshaliases.nix`.

## Dual-boot macOS

The Asahi stub macOS partition remains for firmware updates. Follow [Asahi maintenance docs](https://asahilinux.org/) when updating macOS.
