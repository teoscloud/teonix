# applenix — Asahi installer → teonix flake

One command on the USB installer:

```bash
sudo su
curl -fsSL https://raw.githubusercontent.com/teoscloud/teonix/main/hosts/applenix/install.sh | bash
```

That is the whole USB step. It is idempotent: if anything fails, fix the cause and run the exact same command again — finished steps are skipped.

Default login afterwards: **`teodor` / `teodor`**. Change it on first boot.

---

## Why two stages

| Stage | What | Where |
|-------|------|-------|
| 1 | Minimal console NixOS, plain `configuration.nix` | from the USB, minutes |
| 2 | Full teonix Hyprland rice, flake `#applenix` | from the booted Mac, long |

Stage 1 deliberately does **not** use this flake. Upstream's [`uefi-standalone.md`](https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/uefi-standalone.md) explains why: `nixos-install` only *copies* the Asahi kernel out of the installer when your config's nixpkgs matches the ISO's. Otherwise it tries to **build the kernel inside the installer**, which "is generally not possible due to memory limitations" — and there is [no working upstream binary cache](https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/binary-cache.md) for it.

So stage 1 generates `/mnt/etc/nixos/configuration.nix` against the ISO's own nixpkgs and the `apple-silicon-support` module the ISO plants in `/etc/nixos`. Nothing is pinned, nothing is patched, and the kernel is reused. Stage 2 then switches to the flake from real hardware, where a kernel build is merely slow rather than impossible.

---

## Dynamic on any Apple Silicon Mac

The installer detects capabilities instead of matching model names, so a Mac that ships next year works the same:

| Fact | Source |
|------|--------|
| Target disk | the ESP from `/proc/device-tree/chosen/asahi,efi-system-partition`, then its parent disk — never a hardcoded `/dev/nvme0n1` |
| Root partition | created in free space, then identified by diffing the partition table before and after |
| Laptop vs desktop | a `Battery` in `/sys/class/power_supply` (drives the 80% charge rule) |
| Touch Bar | an `appletbdrm` DRM device or `appletb_backlight` |
| Displays | connected connectors in `/sys/class/drm` (`eDP-1`, `HDMI-A-1`, …) |
| RAM / cores | `/proc/meminfo`, `nproc` — sizes `max-jobs` and the stage 2 swapfile |
| `stateVersion` | `nixos-version`, so it always matches the ISO |
| Peripheral firmware | ESP `vendorfw/firmware.cpio`, otherwise generated from `asahi/` with `asahi-fwextract` |

---

## 0. Before the USB

You need:

- Apple Silicon Mac, macOS 12.3+, admin account, backups
- USB stick ≥512 MB
- [nixos-apple-silicon installer ISO](https://github.com/nix-community/nixos-apple-silicon/releases) — prefer the release matching `apple-silicon.url` in [`flake.nix`](../../flake.nix) (currently **release-2026-07-30**) so stage 2 does not rebuild the kernel either
- Free space for NixOS (leave macOS at least ~20 GB smaller)

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
# from another Linux machine; the disk name will differ
sudo dd if=nixos-asahi-installer.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Hold power, pick **NixOS**, U-Boot should autoboot USB. If it jumps to an old install:

```
# at the U-Boot prompt
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

A USB Ethernet dongle works too.

---

## 2. Stage 1

```bash
curl -fsSL https://raw.githubusercontent.com/teoscloud/teonix/main/hosts/applenix/install.sh | bash
```

Steps, in order, each skipped when already satisfied:

| Step | Does |
|------|------|
| `detect` | reads the hardware facts above into `/tmp/applenix-facts` |
| `net` | refuses to continue offline, prints the `iwctl` recipe |
| `disk` | creates one `8300` partition in the free space (asks you to type `YES`) |
| `format` | `mkfs.ext4 -L nixos`; refuses to touch a non-empty filesystem without `FORMAT=1` |
| `mount` | root on `/mnt`, the Asahi ESP on `/mnt/boot` |
| `firmware` | puts `firmware.cpio` in `/mnt/etc/nixos/firmware` |
| `config` | `nixos-generate-config`, copies the ISO's `apple-silicon-support`, writes `configuration.nix` |
| `install` | `nixos-install --root /mnt --no-root-password` |
| `stage2` | writes `/etc/applenix/stage2.sh` onto the new system |
| `summary` | prints what to do next |

macOS, the iBoot container, the ESP and the Recovery container are never touched.

### Other invocations

```bash
curl … | bash -s status              # live checklist, safe to run any time
curl … | bash -s list                # step names
curl … | bash -s run mount firmware  # only these steps
curl … | bash -s help                # all options
```

If you would rather have the script on disk:

```bash
curl -fsSL https://raw.githubusercontent.com/teoscloud/teonix/main/hosts/applenix/install.sh -o /tmp/install.sh
bash /tmp/install.sh status
bash /tmp/install.sh
```

### Environment overrides

| Variable | Use |
|----------|-----|
| `YES=1` | skip the confirmation prompts |
| `FORCE=1` | redo steps that look finished |
| `FORMAT=1` | allow `mkfs` over an existing filesystem |
| `DISK=/dev/…` | target disk, if ESP detection guesses wrong |
| `ROOT_PART=/dev/…` | use an existing partition instead of creating one |
| `TARGET_USER=` / `TARGET_HOST=` | defaults `teodor` / `applenix` |
| `TOUCHBAR=yes\|no` | override Touch Bar detection |
| `ISO_LAYOUT=0\|1` | `hid_apple iso_layout`, if `` ` `` and `<` are swapped |
| `M1N1_EXTRA=…` | `boot.m1n1ExtraOptions`, for [Mac mini display quirks](https://github.com/AsahiLinux/m1n1/issues/159) |
| `SWAP_SIZE=MiB` | swapfile stage 2 creates (default from RAM) |
| `PKGS_SYSTEM=…` | set if the ISO was cross-built and the kernel still rebuilds |
| `CHARGE_LIMIT=…` | battery ceiling on laptops (default 80) |
| `TEONIX_REPO=` / `TEONIX_DIR=` | what stage 2 clones, and where |

When it finishes:

```bash
reboot
```

Unplug the USB. First boot is a TTY.

---

## 3. Stage 2 → the full rice

Log in as **`teodor` / `teodor`**, then:

```bash
passwd                          # change it now
/etc/applenix/stage2.sh
```

Stage 2:

1. adds a swapfile sized from this Mac's RAM (the flake does rebuild the Asahi kernel)
2. clones teonix to `~/teonix`, or pulls if it is already there
3. copies `/etc/nixos/hardware-configuration.nix` into `hosts/applenix/`, replacing the repo's placeholder UUIDs
4. copies `firmware.cpio` into `hosts/applenix/firmware/`, which is what lets `#applenix` evaluate with **no `--impure`**
5. writes `hosts/applenix/detected.nix` (Touch Bar, m1n1 options, keyboard layout, swap) — safe to commit
6. `sudo nixos-rebuild switch --flake path:.#applenix`

This downloads and compiles a lot. Use `tmux` if you are over ssh.

When it is done, reboot and pick **Hyprland** at the display manager. Later updates are just `systemupdate`.

Commit `hardware-configuration.nix` and `detected.nix` when you are happy. Never commit `hosts/applenix/firmware/` — it is gitignored, and Apple's firmware is not redistributable.

### Always `path:.`, never `.#applenix`

`hosts/applenix/firmware/` is gitignored, and `detected.nix` may be untracked. A git flake reference (`.#applenix`, `git+file:…`) only copies **tracked** files into the store, so both would silently vanish: `peripheralFirmwareDirectory` falls back to `null` and you lose Wi‑Fi, Bluetooth and the camera, with no error.

`path:.` is not git-aware and copies the directory as-is, which is why every teonix alias and stage 2 itself use it:

```bash
sudo nixos-rebuild switch --flake path:.#applenix     # correct
sudo nixos-rebuild switch --flake .#applenix          # drops the firmware
```

---

## 4. Check

| What | How |
|------|-----|
| GPU | `glxinfo \| grep renderer` |
| Wi‑Fi | `nmcli` / `iwctl` |
| Audio | PipeWire, built-in speakers |
| Hyprland | display manager → Hyprland |
| Quickshell | bar on the built-in panel |
| hyprflow | `hfstatus` |

If the panel is not the connector stage 1 reported (see the `Displays:` comment at the top of `hosts/applenix/detected.nix`):

- `home/hosts/applenix/dotfiles/config/hypr/hyprland.conf`
- `home/hosts/applenix/dotfiles/config/quickshell/Globals.qml` (`shellMonitor`)

then `updatehome`.

---

## 5. Troubleshooting

**The Asahi kernel starts building during stage 1.** The ISO and the config disagree. Either the ISO is not from nixos-apple-silicon (stage 1 refuses outright if `/etc/nixos/apple-silicon-support` is missing), or it was cross-built — retry with `PKGS_SYSTEM=x86_64-linux`.

**`could not derive the target disk from the ESP`.** Pass it yourself: `DISK=/dev/nvme0n1 curl … | bash`.

**`several Linux partitions on /dev/nvme0n1`.** The script will not guess. Pick one: `ROOT_PART=/dev/nvme0n1p5 curl … | bash`.

**`no firmware.cpio found`.** Boot macOS, run `curl https://alx.sh | sh`, choose *Rebuild vendor firmware package*, reboot into the installer and re-run `run firmware config`.

**No Wi‑Fi after stage 2.** Confirm `hosts/applenix/firmware/firmware.cpio` exists and is non-empty, then rebuild.

---

## Rescue

USB again → U-Boot: stop autoboot → `bootmenu` → `usb 0`.

```bash
sudo su
curl -fsSL https://raw.githubusercontent.com/teoscloud/teonix/main/hosts/applenix/install.sh | bash
```

It re-mounts what already exists, skips the destructive steps, and re-runs `nixos-install`, which only adds a generation. User data stays.

---

## Dual-boot macOS

Hold power at boot for the picker. The Asahi stub macOS partition stays for firmware updates (`curl https://alx.sh | sh` → rebuild vendor firmware, then rebuild NixOS).

---

## Files

| Path | Role |
|------|------|
| `hosts/applenix/install.sh` | Stage 1 installer, and the source of `/etc/applenix/stage2.sh` |
| `hosts/applenix/asahi.nix` | Kernel, sound, bootloader, firmware for `#applenix` |
| `hosts/applenix/nixconfig.nix` | Hyprland-only session choices |
| `hosts/applenix/hardware-configuration.nix` | **Overwritten by stage 2** — placeholder UUIDs only eval off-device |
| `hosts/applenix/detected.nix` | Written by stage 2; imported by `asahi.nix` when present |
| `hosts/applenix/firmware/` | Local ESP copy, gitignored |
| flake `#applenix` | The full rice |
