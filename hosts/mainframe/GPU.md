# mainframe: GPU, display and suspend

Read this before changing anything about displays, suspend or the graphics card on
`mainframe`. Two hardware facts drive every decision in here.

## Fact 1: there is no onboard video

The board is a Dell Precision Tower 7810 (`0KJCC5`, BIOS A25). It has **no onboard
GPU and no BMC/iDRAC video output**. The card in the PCIe slot is the only POST
path, so if that card is missing or wedged you get:

- no POST output
- **no BIOS access** — you cannot even change firmware settings to recover
- a machine that still boots Linux fine and reaches the graphical target, silently,
  with nothing on any monitor

## Fact 2: a warm reboot cannot clear a wedged card

PCIe slot power survives a warm reboot. Once Polaris is wedged, *every* subsequent
reboot repeats the same failure, because the card is never actually re-powered.

### What happened on 2026-09-10

From the journal, boot by boot:

- **Boot -7** ended with `systemd-logind: The system will suspend now!`, then
  `PM: suspend entry (deep)` at `00:14:40`. No resume was ever logged.
- **Boots -6 through -1** — six consecutive boots — contain **zero**
  `pci 0000:05:00.0` lines, no `vgaarb: setting as boot VGA device`, no
  `simple-framebuffer` and zero `amdgpu` lines. The GPU was absent from the PCI
  bus entirely. The NVMe at `04:00.0` enumerated normally, so the bus was fine.
- **Boot 0**, after a CMOS reset and reseating the card, shows the GPU back with
  its usual 56 PCI lines.

Searching the whole journal for suspend events returns exactly one: `00:14:40`,
precisely the boundary. So the chain was:

> ACPI S3 cut GPU context → Polaris failed to re-POST on resume → card wedged →
> slot power survived each warm reboot → Dell UEFI could not enumerate the card and
> never ran its GOP → no POST video, no BIOS → only a full power drain cleared it.

The number of monitors and the 120 Hz mode were **not** the cause. A compositor
cannot un-enumerate a PCI device.

## Getting into the BIOS / boot menu (blank-screen workaround)

The Dell setup UI (F2) and boot menu (F12) switch to a video mode the G9 will not
sync over DP, so they show "signal but black". The GOP text modes are fine — the
`_` cursor and boot messages prove video works — it is only the firmware UI.

Procedure for any firmware work:

1. Power off. Unplug the G9's DP cable.
2. Connect **only** a plain 1080p monitor over HDMI (the ASUS VG245 works).
3. Boot and press F2 (setup) or F12 (boot menu / BIOS Flash Update).
4. Reconnect the G9 afterwards.

Optional: setting the G9's OSD DisplayPort version to 1.2 sometimes helps, but the
single-1080p-monitor route is the reliable one.

### BIOS update (recommended: A25 is from Feb 2018)

The latest Dell release for the T7810 is **A34**. fwupd/LVFS cannot flash this
board ("UEFI capsule updates not available"), so use Dell's USB path:

1. Download `T7810A34.exe` from Dell support (Precision Tower 7810 -> BIOS).
2. Copy it onto any USB stick (does not need to be bootable), plug it in.
3. Boot with the 1080p monitor (see above), press F12, pick **BIOS Flash Update**,
   browse to the file, flash. Do not cut power during the flash.

Notes: BIOS A12+ is one stream with no upgrade restrictions from A25. Do not
downgrade below A12 with v4 (Broadwell) Xeons installed.

## Storage: the NVMe is sensitive to reseating

On 2026-09-10, after the NVMe adapter moved to a different slot, the root disk
dropped writes mid-session (`Buffer I/O error`, `lost async page write`, journald
unable to rotate). This platform denies the OS AER control on several bridges, so
PCIe link errors mostly do NOT appear in the journal — a clean log proves nothing.

- `teonix-storage-health` (in `gpu-guard.nix`) tracks NVMe SMART error counters
  across boots and prints a warning at login when they grow.
- Manual check: `sudo smartctl -a /dev/nvme0`; link state:
  `sudo lspci -vv -s <nvme bdf> | grep Lnk`.
- If errors recur: power off, reseat the M.2 in its adapter and the adapter in the
  slot; if they persist in that slot, use a different one (any x4 slot is enough).
- After any lost-write incident, force a full fsck on the next boot:
  `sudo touch /forcefsck` (systemd initrd honors it), then check the boot journal.

## Recovery when there is no video at all

Do this **instead of** a CMOS reset — the CMOS was never the problem, it just
happened to involve the power drain that actually fixed things:

1. Shut down, then switch off and **unplug the PSU**.
2. Hold the power button for ~15 seconds to drain standby rails.
3. Plug back in and power on.

Only reseat the card if a drain alone does not bring it back. If you have another
machine, note that Linux itself boots fine while headless: SSH in and check
`lspci | grep -i vga` to confirm whether the card is on the bus.

## Fact 3: the display bandwidth ceiling (RX 580 only)

The RX 580 is a Sapphire RX 580 (Polaris 10, `1002:67df`, DCE 11.2). The G9 at
`5120x1440@120` 8bpc needs about **25.4 Gbps** against DP 1.4 HBR3's **25.92 Gbps**
usable. That leaves nothing for a second pipe, so DCE 11.2 cannot validate a second
output while the G9 is at 120 Hz. It shows up as an endless

```
atomic drm request: failed to commit: Invalid argument
```

storm, or as Hyprland simply refusing the modeset and keeping the previous mode.

This is a hard ceiling, not a configuration problem. **`5120x1440@120` is banned
outright on this card** via a per-output pixel-rate budget
(`TEONIX_MAX_PIXEL_RATE_MPS=500`): that mode is ~885 Mpx/s, while the two
sanctioned G9 modes — `2560x1440@120` (the default) and `5120x1440@60` (`Super+S`)
— are both ~442 Mpx/s and were verified live on 2026-09-10 with two extra 1080p60
outputs attached. `display-safe.sh` never selects a mode above the budget, for any
monitor in any port.

The ban belongs to the card, not to the machine, so it is applied by card:
`teonix-gpu-profile` reads the fitted display device from the PCI bus at every
boot and writes the budgets to `/run/teonix/display-bandwidth.conf`. Fit a
DSC-capable card and the ban is simply not written that boot. The profiles live in
`hosts/mainframe/gpu.nix`; `/etc/teonix/display-bandwidth.conf` holds the RX 580's
numbers as a fallback for the case where that service did not run, because being
stuck at 60 Hz is cheaper than letting an over-budget mode through on Polaris.

### The greeter: NEVER give mutter a stored monitors.xml

**Hard rule, written in six boots of scar tissue (2026-09-10): any stored
`monitors.xml` that matches the connected monitors leaves the login screen
black. Mutter's own improvised layout always works.** `teonix-greeter-unpin`
deletes `/var/lib/gdm/seat0/config/monitors.xml` before every greeter start,
and nothing installs `/etc/xdg/monitors.xml`. That absence *is* the greeter
configuration.

| Boot | Stored config the greeter saw | Page-flip failures | Result |
| --- | --- | --- | --- |
| 13:24 | ultrawide-only pin, matched nothing (3 monitors attached) | 6 | worked |
| 13:38 | same non-matching pin → mutter improvised | 0 | worked, all 3 attached |
| 14:24 | generated: 3 outputs, G9 at 5120 | 170 | black |
| 14:57 | generated: G9 only, 5120 | 114 | black |
| 15:14 | generated: G9 only, 2560 | 104 | black |
| 15:36 | generated: Samsung 27 only, plain 1920x1080@60 | 110 | black |

The last row kills every mode theory: a single 1080p60 output is the most
trivial commit that exists and it still failed
(`Page flip failed: drmModeAtomicCommit: Invalid argument`, forever). Resolution,
refresh, panel choice, output count — all irrelevant. What matters is *how* the
layout was chosen: mutter treats a stored config as policy and hammers a commit
this amdgpu/DCE 11.2 combination rejects, but a layout it negotiated itself gets
degraded until something sticks. A watchdog that restarted GDM after a failure
was tried and did not help — mutter just forced the stored config again.

The original fear behind pinning — that improvised mutter would commit the
banned `5120x1440@120` — never materialised: every unpinned boot (all of them
before 13:07, plus 13:24 and 13:38) came up fine, and the kernel refuses
over-budget multi-output combos on its own. The greeter dialog may sit
off-centre on the ultrawide; that is cosmetic and is the price of a login
screen that displays.

Connector names move: reseating the card on 2026-09-10 swapped the ultrawide from
`DP-2` to `DP-1`. Hyprland's `desc:` rules absorbed that with no changes, which
is exactly why nothing may ever name a port.

Note that a stale `~/.config/monitors.xml` **overrides** `/etc/xdg` for a GNOME
session. This machine had one left over from January pinning the ultrawide at
`239.761` Hz. It is irrelevant under Hyprland, but delete it before ever starting
a GNOME session.

## What is in place

### System (`hosts/mainframe/`)

| File | Purpose | Card-specific? |
| --- | --- | --- |
| `gpu.nix` | GPU and display policy for whatever card is fitted | No — only the budget table inside it is |
| `gpu-guard.nix` | Board-level no-video protection | No — keep it |
| `platform.nix` | Hibernate tier (`resumeDevice`, swap, `HibernateDelaySec`) | No |

`gpu.nix` is written so that **the machine boots with either card and needs no
rebuild to swap them**. That matters because the card in the slot is the only POST
path: if the new card turns out to be a problem, the old one has to be able to go
back in and boot, and asking a headless machine for a rebuild first is not a plan.
It sets:

- `hardware.amdgpu.initrd.enable` plus `boot.initrd.kernelModules = [ "i915" ]` —
  both display drivers load from the initrd, and the one whose card is absent
  simply binds nothing. Coldplug is not trusted: on 2026-09-10 udev silently failed
  to insert amdgpu (all DRM deps loaded, module never appeared) and the session
  degraded to simpledrm + llvmpipe with one fake `Unknown-1` output and no EDID.
  Never load a DRM driver by hand into such a session — the takeover kills the
  compositor to a TTY. Having only `i915` in the initrd also settles who drives an
  Arc card: kernel 6.18 has **both `i915` and `xe`** advertising `8086:56a0/56a1/56a5`
  with empty `force_probe` lists, so first module loaded wins, and that is `i915`.
- `hardware.enableRedistributableFirmware` — DG2 does not initialise without
  `dg2_guc_70.bin`, `dg2_huc_gsc.bin` and `dg2_dmc_ver2_*.bin`. All three are in
  the initrd (verified in the built image), so the card comes up in early KMS.
- `intel-media-driver` and `vpl-gpu-rt` in `hardware.graphics.extraPackages` for
  VAAPI/QSV on Gen12+. Mesa already supplies rendering (iris, ANV); the AMD ROCm
  ICDs from `modules/hardware/hardware-x86.nix` stay, inert without their card.
- `services.xserver.videoDrivers = [ "modesetting" ]`, overriding the `[ "amdgpu" ]`
  pin that `modules/services/system-services.nix` applies to every x86 host. That
  pin would leave Xorg with no driver the moment the card is not AMD. The Wayland
  sessions do not consult it at all.
- `mem_sleep_default=s2idle` and `SuspendState=freeze` — suspend still works, but
  the GPU keeps power, so the resume re-POST that wedged Polaris never happens.
  Kept for the Arc too: Alchemist has no such known bug, but s2idle costs a few
  watts while a failed resume on this chassis costs a power drain with no BIOS
  access in between, and long sleeps land in S4 anyway.
- `amdgpu.runpm=0` and `amdgpu.gpu_recovery=1` — module parameters, ignored when
  amdgpu is not driving anything, so they can stay for the RX 580's sake.
- `teonix-gpu-profile` — reads the fitted display device from the PCI bus before
  the greeter starts and writes that card's budgets to
  `/run/teonix/display-bandwidth.conf` (RX 580: 60 Hz / 500 Mpx/s; Arc DG2:
  240 Hz / 2000 Mpx/s, which permits `5120x1440@240`). An unrecognised card gets
  the permissive numbers plus a notice at login. `/etc/teonix/display-bandwidth.conf`
  carries the RX 580 numbers as the fallback if the service never ran;
  `display-safe.sh` prefers `/run`, falls back to `/etc`, and applies **no limits
  at all** if neither exists.
- `teonix-greeter-unpin` — see the greeter rule above. Kept across the swap because
  its only cost is a greeter that does not remember its layout.

`gpu-guard.nix` adds two units. Both locate the GPU by **PCI display class**
(`0x03....`), never by bus address, vendor or driver name:

- `gpu-resume-guard` runs after every resume. It waits a few seconds for the device
  to reappear with a bound driver and at least one readable DRM connector. If that
  fails it tries a PCI reset, and if *that* fails it **powers off rather than
  rebooting** — because a reboot provably cannot recover this state.
- `gpu-boot-guard` catches the state that actually stranded the machine: booting
  with no display device on the bus at all. It powers off after a 60 second SSH
  grace period so the next start is a cold one. A marker under `/var/lib/teonix/`
  means it does this **once**; if the next boot is still headless it stays up so
  SSH remains available. It cannot loop. When the device exists but no kernel
  driver binds within 30 s (the silent llvmpipe degradation), it **warns only** —
  journal plus a login note — because such a session is usable and a reboot fixes it.
- `teonix-storage-health` compares NVMe SMART error counters against the previous
  boot and warns at login when they grew. See the storage section above.

Escape hatch, since both units can power the machine off:

```bash
sudo touch /etc/teonix/no-gpu-guard    # persistent
```

or add `teonix.no_gpu_guard` to the kernel command line for a single boot. Use this
if you ever want to run this box deliberately headless with no card fitted.

The hibernate tier means long sleeps land in S4, where the **firmware** POSTs the
GPU on the way back — the path that always works on this board.

### Session (`home/hosts/nixbox/dotfiles/config/hypr/`)

`scripts/display-safe.sh` owns every mode change. It names no connector, no DRM card
index and no monitor: outputs come from `hyprctl monitors all -j`, the primary is
whichever panel can show the most pixels, and every modeset is checked against
`/sys/class/drm/card*-<name>/enabled` because Hyprland reports a mode even when the
atomic commit failed.

| Command | Used by | Behaviour |
| --- | --- | --- |
| `ultrawide` | `Super+S` | Primary at its largest allowed mode (`5120x1440@60`), others on |
| `highrefresh` | `Super+D` | Primary at its fastest allowed mode (`2560x1440@120`), others on — the default |
| `safe` | `Super+Shift+D` | Panic: collapse to one known-good output |
| `verify-or-revert` | both live modes | Reverts if the output went dark; warns if the mode was merely refused |
| `save-and-deescalate` | `hypridle` pre-sleep | Remember the layout, then go safe |
| `restore` | `hypridle` post-sleep | Put the layout back, or go safe if it cannot |
| `watchdog` | `exec-once` | If every output is ever dark, reload and recover in-session |

`scripts/main-monitor.sh` is the one display script that changes **no** mode, so
it sits entirely outside the pixel-rate ban. It only moves the *designation* of
"main": the set of workspaces pinned to main (read live from
`hyprctl workspacerules`, so the config stays the only place that decides which
those are) plus Quickshell's bar, dock and overlays (via its `mainmonitor` IPC
handler). Workspaces that were never pinned to main stay put, so the receiving
output keeps its own and gains main's on top.

| Command | Used by | Behaviour |
| --- | --- | --- |
| `toggle` | `Super+Esc` | Bounce between the current main and the previous one |
| `next` | `Super+Shift+Esc` | Walk every active output, in EDID-description order |
| `set SEL` | — | Make a connector name or `desc:` prefix main |
| `status` | — | Report the current main, the cycle order and main's workspaces |

State lives in `$XDG_RUNTIME_DIR/teonix-display/`, so it never survives a reboot
and a stale entry is ignored the moment that output stops being connected.

Two sharp edges, both cosmetic. `hyprctl reload` re-reads the config and pins the
workspace rules back to their configured output, while workspaces already moved
stay where they are — press the bind again to line things up. And an output left
with no workspace at all gets a fresh empty one from Hyprland, which takes the
lowest free number rather than obeying the rules; it holds no windows and is
destroyed again the moment that output gets a real workspace.

`hypridle`'s `before_sleep_cmd`/`after_sleep_cmd` hook logind's `PrepareForSleep`,
so they run for **every** suspend, not just idle-triggered ones. That means the
resume modeset is always the least demanding one possible.

Monitors in `hyprland.conf` are matched by EDID description prefix (`desc:`), with
an empty-name catch-all last so any unknown panel in any port still gets a sane
mode. The serial is deliberately omitted from the prefix: some panels report a
different serial per port — the S27E590 gives `HTQGA01931` on DP but `0x304D4645`
on HDMI. Get a prefix with `hyprctl monitors` and drop the trailing serial.

## Swapping the GPU

Nothing to rebuild. `gpu.nix` already carries both drivers, both firmware sets and
both userspace stacks, and the display budgets are chosen from the PCI bus at boot,
so the swap is: shut down, change the card, boot. The same is true in reverse — the
RX 580 goes back in and boots unchanged, which is the escape hatch for a card that
does not work out.

**Do a `nixos-rebuild boot` with the current card still fitted** before touching
hardware, though. The point is that the *running* generation must already be the
card-agnostic one; discovering it is not, on a machine whose only display output is
the card you just removed, is the bad ending.

### Before the swap (with the old card still in)

```bash
cd ~/teonix && nixupgrade        # or: sudo nixos-rebuild switch --flake .#mainframe --impure
systemctl status teonix-gpu-profile          # should report the RX 580 profile
cat /run/teonix/display-bandwidth.conf       # 60 / 500 while Polaris is fitted
```

### Intel Arc A750 (DG2) specifics

- **Firmware/BIOS must be UEFI, not legacy.** Arc cards ship a UEFI GOP only — they
  have **no legacy VGA BIOS**. With CSM / legacy option ROMs driving video there is
  no POST output at all on this board. This install already boots UEFI
  (systemd-boot on the ESP), so leave it that way and prefer "UEFI only" in setup.
- **Enable large-address decoding** ("Above 4GB decoding" / "Memory Mapped I/O
  above 4GB") if the T7810 setup offers it. DG2 wants a big BAR window and old
  firmware that keeps everything under 4 GB can fail to allocate it. If the card
  enumerates but never binds (`i915` probe failure over BAR allocation), add
  `pci=realloc` to `boot.kernelParams` in `platform.nix` as a fallback.
- **No Resizable BAR on BIOS A25/A34.** Alchemist loses noticeable performance
  without ReBAR. It is not a boot issue and there is no fix on this platform.
- **PCIe 3.0 x16** is what this board offers; the A750 is PCIe 4.0 x8 and
  negotiates 3.0 x8 fine.
- Remember the firmware-UI trick from the top of this file: to reach F2/F12, run a
  plain 1080p panel on HDMI, because the G9 will not sync the setup UI's mode.

### After the first boot on the new card

```bash
lspci -nn | grep -iE 'vga|display'           # expect 8086:56a1 for the A750
ls -l /sys/class/drm/card*/device/driver     # expect .../drivers/i915
systemctl status teonix-gpu-profile          # expect the Arc profile
cat /run/teonix/display-bandwidth.conf       # expect 240 / 2000
journalctl -b -k | grep -iE 'i915|GuC|HuC|DMC' | head -30
glxinfo -B 2>/dev/null | grep -i 'renderer'  # must NOT say llvmpipe
vainfo 2>/dev/null | head -5                 # iHD driver, hardware decode
```

Then, in this order:

1. **Suspend once with an SSH session open from another machine.** Policy is
   unchanged (`s2idle`), so this should be uneventful; confirm the outputs come back
   before trusting it.
2. **Escalate the display**: `Super+D` now derives `5120x1440@240` for the G9
   instead of `2560x1440@120`, and `verify-or-revert` still reverts if the commit
   does not stick. Once it survives a reboot and a resume, raise the startup pin on
   the `desc:Samsung Electric Company LC49G95T` line in `hyprland.conf` — it is
   deliberately left at the mode that commits on either card.
3. **Prune the AMD leftovers** only after the Arc has proven itself for a while:
   the ROCm ICDs in `modules/hardware/hardware-x86.nix` (shared with `nixbox`, so
   check that host first), `hardware.amdgpu.initrd.enable`, and the two
   `amdgpu.*` kernel parameters. Keeping them is what makes putting the 580 back a
   non-event, so there is no hurry.

Unchanged by any swap: the `desc:` monitor rules (port- and card-agnostic), the
greeter's no-`monitors.xml` rule, and `gpu-guard.nix`.

## Quick checks

```bash
cat /sys/power/mem_sleep                      # expect: [s2idle] deep
systemctl status gpu-resume-guard gpu-boot-guard
systemctl status teonix-gpu-profile           # which card, which budgets
cat /run/teonix/display-bandwidth.conf        # budgets in force this boot
systemctl status teonix-storage-health        # loud if NVMe error counters grew
lspci -nn | grep -iE ' vga | display '        # is the card even on the bus?
ls -l /sys/class/drm/card*/device/driver      # driver actually bound?
for f in /sys/class/drm/card*-*/enabled; do echo "$f $(cat $f)"; done
~/.config/hypr/scripts/display-safe.sh safe   # recover a bad layout by hand
```
