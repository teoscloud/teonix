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
| `BUILD_CORES=N` | cores per derivation in stage 2 (default from RAM); lower it if a build is OOM-killed |
| `KERNEL_BUILD_OK=1` | let stage 2 compile the Asahi kernel instead of refusing (2h+; normally a sign the pin is wrong) |
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

1. adds a swapfile sized from this Mac's RAM — 16 GiB on an 8 GiB Mac — and switches zram off so those pages reach the disk instead of RAM. Insurance only: the kernel should not rebuild (see below)
2. clones teonix to `~/teonix`, or brings an existing checkout to exactly upstream — local edits to tracked files are stashed first, because a `pull` alone leaves clobbered files in place
3. copies `/etc/nixos/hardware-configuration.nix` into `hosts/applenix/`, replacing the repo's placeholder UUIDs
4. copies `firmware.cpio` into `hosts/applenix/firmware/`, which is what lets `#applenix` evaluate with **no `--impure`**
5. writes `hosts/applenix/detected.nix` (Touch Bar, m1n1 options, keyboard layout, swap) — safe to commit
6. `sudo nixos-rebuild switch --flake path:.#applenix --option max-jobs 1 --option cores N`, with `N` from RAM (2 on an 8 GiB Mac)

### Why the kernel is not rebuilt

There is **no Asahi kernel binary to download.** Checked four ways, all agreeing:

- [`docs/binary-cache.md` on `main`](https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/binary-cache.md): *"we do not currently have a working cache"* — their GH runners are too slow to build the kernel and the alternative runners can't sandbox
- upstream's `flake.nix` declares no `nixConfig.extra-substituters`, so nothing is offered automatically
- `nixos-apple-silicon.cachix.org` still resolves, but returns **404 for every candidate**: `main` and `release-2026-07-30`, native and cross-built alike. [Issue #431](https://github.com/nix-community/nixos-apple-silicon/issues/431) is Cachix having garbage-collected the old NARs
- `cache.nixos.org` will never carry it: nixpkgs policy keeps vendor kernels out of the tree, the same reason the Raspberry Pi kernels moved to nixos-hardware. The long-term plan is to share that Hydra — [nixos-hardware#854](https://github.com/NixOS/nixos-hardware/issues/854)

So whoever evaluates the kernel compiles it: two hours plus, and it OOMs an 8 GiB Mac.

The documented way to avoid that is not to download it but to *not ask for a different one than you already have*. From upstream's [`uefi-standalone.md`](https://github.com/nix-community/nixos-apple-silicon/blob/main/docs/uefi-standalone.md):

> If the installed NixOS version matches the version used by the installer […] and if the installer has not been cross-compiled (the default for official releases), the kernel will be copied over from the installer. Otherwise, the system will attempt to build the kernel in the installer environment which is generally not possible due to memory limitations.

That is exactly what stage 1 relies on, and what `hosts/applenix/asahi.nix` extends to stage 2 by setting `hardware.asahi.pkgs` to apple-silicon's **own pinned nixpkgs** instead of ours:

```nix
asahiPkgs = import apple-silicon.inputs.nixpkgs {
  system = "aarch64-linux";
  overlays = [ apple-silicon.overlays.default ];
};
```

That reproduces the exact derivation stage 1 installed, so the switch reuses the kernel already in the store and compiles nothing. Two consequences worth knowing:

- **The kernel no longer tracks `nixos-unstable`.** Previously `apple-silicon.inputs.nixpkgs.follows = "nixos-unstable"` meant every `systemupdate` changed the kernel's hash and triggered a fresh multi-hour build. Now only bumping the `apple-silicon` input moves it, and that one build is unavoidable.
- **Nothing is cross-compiled.** `pkgsSystem` is left at `aarch64-linux`, so every derivation in the closure is still natively buildable on the Mac. If a prebuilt path is ever missing the Mac compiles it — slow, but it cannot hard-fail the way a `localSystem = x86_64-linux` closure would.

There are **two** prebuilt kernels a release can produce, and they are different store paths:

| ISO / stage 1 | `hardware.asahi.pkgsSystem` | kernel path |
|---|---|---|
| official native ISO | `aarch64-linux` | `fyrv4wlxlq966sf5j0a8jwvf9xavxna1-linux-asahi-7.1.5` |
| cross-built ISO, or `PKGS_SYSTEM=x86_64-linux` in stage 1 | `x86_64-linux` | `5zgarn52876f6w4k61bc99shn3k64qdd-linux-asahi-aarch64-unknown-linux-gnu-7.1.5` |

Asking for the wrong one means compiling from scratch, so stage 2 works out which is actually in the store — it asks the pinned `apple-silicon` input for both candidates and tests each with `nix path-info`, rather than guessing from kernel names (the target triple in a kernel's name is not a reliable cross-build tell; nixbox's own native kernel has one). It then writes the answer to `hosts/applenix/asahi-build-system.nix`, a one-line file that `asahi.nix` reads as plain data:

```nix
"x86_64-linux"
```

Read as plain data on purpose — going through `config` would make the `nixpkgs.overlays` in `asahi.nix` depend on the module system while it is still constructing `pkgs`. Like `firmware/`, this file only takes effect via `path:.`; a git flake reference would drop it while it is untracked.

One consequence of the cross case: 1,077 derivations in that closure declare an x86_64 builder (the whole cross toolchain). They never get realised as long as the outputs we need are present, which is exactly why stage 1 could reuse the ISO's kernel without a cross compiler. If one *is* missing, Nix fails immediately with `cannot build on 'x86_64-linux'` rather than compiling for hours — a loud failure, not a slow one.

The native case is deterministic, not a lucky hash collision:

| Fact | Value |
|---|---|
| `release-2026-07-30` is a git **tag**, not a branch | `66d8dd2c…`, cannot move |
| its published ISO | `nixos-26.11.20260723.e2587ca-aarch64-linux.iso` |
| ISO platform | `aarch64-linux` — native, not cross-built |
| ISO's nixpkgs | `e2587ca…`, which is exactly what the apple-silicon flake pins |
| resulting kernel | `fyrv4wlxlq966sf5j0a8jwvf9xavxna1-linux-asahi-7.1.5` |

Because the tag is immutable and the ISO is native, `#applenix` resolves to the same kernel path the installer copied into the store. Since `flake.lock` is gitignored, pinning by tag rather than branch is what keeps this reproducible.

Stage 2 verifies it before committing to a long run, and refuses to start a kernel build unless you pass `KERNEL_BUILD_OK=1`. To check by hand:

```bash
nix path-info "$(nix eval --raw path:$HOME/teonix#nixosConfigurations.applenix.config.boot.kernelPackages.kernel)"
```

A path means it's already in the store. `path does not exist` means it would be built, which means the `apple-silicon` input no longer matches the ISO this Mac was installed from — fix the pin, don't sit through the build.

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

**`Out of memory: Killed process … (nix)` / `builder … died with signal SIGKILL` during stage 2.** This was the Asahi kernel compiling, which should no longer happen at all — see [Why the kernel is not rebuilt](#why-the-kernel-is-not-rebuilt). If some other derivation is being killed, three mitigations are in place:

- the swapfile was 8 GiB; it is sized from RAM, 16 GiB on an 8 GiB Mac
- `zram` sits at a higher swap priority than a file, so the build was compressing pages into the RAM it was short of instead of spilling to disk — stage 2 turns zram off first
- the build used every core, and peak memory scales with that — stage 2 now passes `--option max-jobs 1 --option cores 2` on an 8 GiB Mac

Nothing already built is lost. Refresh the helper and re-run; it picks up where it stopped:

```bash
cd ~/teonix
git fetch origin && git reset --hard origin/main
sudo TARGET=/ FORCE=1 bash hosts/applenix/install.sh run stage2   # rewrite /etc/applenix/stage2.sh
/etc/applenix/stage2.sh
```

If it is still killed, drop to one core — slow, but it finishes:

```bash
BUILD_CORES=1 /etc/applenix/stage2.sh
```

Watch it with `watch -n5 free -h` in another TTY (Alt+F2). Swap filling up is normal and fine; swap *full* plus zero free RAM is the failure.

**`function 'anonymous lambda' called with unexpected argument 'ignoreConfigErrors'`.** `~/teonix` is a stale checkout. The retired `bootstrap.sh` used to overwrite tracked files in place, and `git pull --ff-only` reports *"Already up to date."* without reverting them, so the build used the old `asahi.nix`. `linux-asahi` dropped that argument in `release-2026-07-30`.

```bash
cd ~/teonix
git status --short                       # shows the clobbered files
git fetch origin
git reset --hard origin/main
/etc/applenix/stage2.sh
```

Stage 2 does this itself now: it stashes local edits to tracked files, hard-resets to upstream, and refuses to start a build if any `.nix` file in `hosts/applenix/` still passes `ignoreConfigErrors`. That check looks at `.nix` files only and strips comments first — the word also appears in `install.sh`, in this document, and in a comment in `asahi.nix`, so a plain recursive grep fails a checkout that is perfectly fine. To refresh the helper on an already-booted Mac:

```bash
sudo TARGET=/ FORCE=1 bash ~/teonix/hosts/applenix/install.sh run stage2
```

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
