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
(`TEONIX_MAX_PIXEL_RATE_MPS=450`): that mode is ~885 Mpx/s, while the two
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

### The greeter: NEVER give mutter a stored monitors.xml (RX 580 era — lifted 2026-09-21)

*Historical, Polaris-only. `teonix-greeter-unpin` was removed with the Arc fitted;
on i915 a stored greeter layout is what pins GDM to the single-pipe 120 Hz mode.*

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
| `compositor-core.nix` | Hyprland's render thread gets physical core 2 (+HT 30) to itself; see "Compositor core" below | No — GPU IRQ is found by driver name (`i915`/`xe`/`amdgpu`) |

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
- `teonix-gpu-profile` — reads the fitted display device from the PCI bus before
  the greeter starts and writes that card's budgets to
  `/run/teonix/display-bandwidth.conf` (RX 580: 60 Hz / 450 Mpx/s; Arc DG2:
  240 Hz / 2000 Mpx/s, no ban — the two-pipe `5120x1440@240` works once the G9 is
  in the last DP connector, see the 2026-09-21 notes below). An unrecognised
  card gets permissive numbers plus a notice at login.
  `/etc/teonix/display-bandwidth.conf` carries the RX 580 numbers as the fallback
  if the service never ran; `display-safe.sh` prefers `/run`, falls back to `/etc`,
  and applies **no limits at all** if neither exists.

Removed 2026-09-21 with the Arc fitted (Polaris-only; history above still
explains why they existed): `mem_sleep_default=s2idle` + `SuspendState=freeze`,
`amdgpu.runpm=0` + `amdgpu.gpu_recovery=1`, `hardware.amdgpu.initrd.enable`, and
`teonix-greeter-unpin` (the greeter may keep its `monitors.xml` again — on the
Arc that is how GDM remembers `5120x1440@120`).

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
| `ultrawide` | `Super+S` | Primary at its largest allowed mode, fastest refresh (Arc: `5120x1440@240`, the default; RX 580: `5120x1440@60`), others on at ≤ `TEONIX_SECONDARY_REFRESH_CAP` (60) |
| `ultrawide` with `TEONIX_MAX_PIXEL_RATE_MPS=900` | `Super+Ctrl+S` | Single-pipe fallback (Arc: `5120x1440@120`) for when the two-pipe 240 comes up wrong; works blind |
| `highrefresh` | `Super+D` | Primary at its fastest allowed mode (Arc: also `5120x1440@240`; RX 580: `2560x1440@120`), others on |
| `safe` | `Super+Shift+D` | Panic: collapse to one known-good output |
| `verify-or-revert` | both live modes | Reverts if the output went dark; warns if the mode was merely refused |
| `save-and-deescalate` | `hypridle` pre-sleep | Remember the layout, then go safe |
| `restore` | `hypridle` post-sleep | Put the layout back, or go safe if it cannot |
| `watchdog` | `exec-once` | If every output is ever dark, reload and recover in-session |
| `follow` | `exec-once` | After every `monitoradded` burst, re-anchor the layout as `ultrawide` would (no-op if already right), then restore scrolling-layout column widths in pixels via `scroll-columns.py` (Hyprland stores them as fractions of the workspace, so 5120→2560 would otherwise halve every column). Every 5 quiet seconds, re-place any secondary that drifted off the primary's *current* footprint (positions only, so a deliberate Super+Ctrl+S fallback is left alone). Makes the G9's PIP toggle — a DP reconnect with a 2-block EDID, 2560x1440@120 max — land in a contiguous layout instead of leaving the secondaries at their 5120-wide anchors. Logs to `$XDG_RUNTIME_DIR/teonix-display/follow.log` |

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

Monitors in `hyprland.lua` are matched by EDID description prefix (`desc:`), with
an empty-name catch-all last so any unknown panel in any port still gets a sane
mode. The serial is deliberately omitted from the prefix: some panels report a
different serial per port — the S27E590 gives `HTQGA01931` on DP but `0x304D4645`
on HDMI. Get a prefix with `hyprctl monitors` and drop the trailing serial.

The config is Lua (`hyprland.lua`, Hyprland ≥ 0.55; hyprlang `.conf` is gone in
0.57). With the Lua manager `hyprctl keyword` does not exist and `hyprctl dispatch`
takes `hl.dsp.*` calls, so every script here drives Hyprland through
`hyprctl eval 'hl.monitor({...})'` / `hl.dispatch(...)` / `hl.config({...})`
(display-safe.sh's `hypr_monitor` wraps the monitor rule; main-monitor.sh,
focus-column.sh, cyclemon.sh, scroll-columns.py, qs-live-ipc.sh, qsmainframe.sh,
qsglass.sh and the Quickshell QML were ported the same day, 2026-09-22).
`hl.monitor` merges into the existing rule for that output, so a re-enable must
pass `disabled = false` explicitly — the helper always does.

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
cat /run/teonix/display-bandwidth.conf       # 60 / 450 while Polaris is fitted
```

### Intel Arc A750 (DG2) specifics

- **Firmware/BIOS must be UEFI, not legacy.** Arc cards ship a UEFI GOP only — they
  have **no legacy VGA BIOS**. With CSM / legacy option ROMs driving video there is
  no POST output at all on this board. This install already boots UEFI
  (systemd-boot on the ESP), so leave it that way and prefer "UEFI only" in setup.
- **Enable large-address decoding** ("Above 4GB decoding" / "Memory Mapped I/O
  above 4GB") if the T7810 setup offers it. It is already on: BAR 2 sits at
  `0x33fe0000000`. That switch only allows addresses past 4 GB. It does not
  grow the window. Turning it off leaves the card at 256 MiB, which is where
  it already is.
- **No Resizable BAR menu on BIOS A25/A34.** The firmware ships a 256 MiB
  prefetch window and never grows it. That is a performance problem, not a boot
  problem, and it is not a missing NixOS package. `pci=realloc` (2026-09-23)
  tried and died with `Failed to resize BAR2 to 8192M (-ENOSPC)` on the switch
  ports. `pci=realloc,nocrs` the same night ignored the Above-4G window
  `0x30000000000-0x33fffffffff`, so `i915_resize_lmem_bar` never called
  `pci_resize_resource` and logged `Can't resize LMEM BAR - platform support
  is missing`. Both parameters are out of `gpu.nix`. The userspace setup is
  the [NixOS Intel Graphics](https://wiki.nixos.org/wiki/Intel_Graphics) Arc
  example: modesetting, `intel-media-driver`, `vpl-gpu-rt`, `LIBVA_DRIVER_NAME=iHD`,
  firmware, `i915.enable_guc=3`. `intel-compute-runtime` is the wiki's optional
  OpenCL runtime and is not installed.
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

### What the first day on the Arc taught (2026-09-21)

- **240 Hz works — but the G9 must be in the card's last DisplayPort connector.**
  The G9 in full (non-PIP) mode hands i915 a 3-block EDID with `5120x1440@239.76`
  as preferred, and the kernel keeps it — no EDID override needed. That mode's
  1.94 GHz pixel clock needs two DG2 pipes ("bigjoiner") plus DSC, and i915 takes
  the pipe *right after* the primary's as the second one. Pipes are handed out
  first-fit in connector order — by the kernel console at boot, by mutter
  (`find_unassigned_crtc`) and by Hyprland's aquamarine (`recheckCRTCs`) — and no
  compositor lets you pick one. With the G9 in `DP-2` it sat on pipe B, the S27 in
  `DP-4` held pipe C, and every 240 modeset from Hyprland failed the atomic test
  with `EINVAL`; the 240 that GDM/GNOME did manage came out as a magnified top-left
  quarter. Moving the G9 to `DP-4` (swapped with the S27) gives A=ASUS, B=S27, C=G9,
  D free: `5120x1440@239.76` committed with all three outputs lit and renders
  correctly. Note the card's HDMI port is a DP output behind a PCON and enumerates
  as `DP-1` (`subconnector = HDMI`). The Arc budget is **2000 Mpx/s** (no ban);
  `Super+Ctrl+S` passes 900 to fall back to the single-pipe `5120x1440@120` blind.
  The GDM greeter is deliberately pinned to `5120x1440@120` in `/etc/xdg/monitors.xml`
  — a login screen gains nothing from 240 and a broken greeter is a blind login.
- **In PIP mode the G9 sends a 2-block EDID** that stops at `2560x1440@120`.
  That is where the "Linux only sees 1440p" symptom comes from; it is the panel,
  not the driver. Toggling PIP is a full DP disconnect/reconnect; Hyprland then
  falls back to the PIP EDID's preferred mode but keeps the secondaries at their
  5120-wide anchors, so `display-safe.sh follow` (an `exec-once`) re-anchors the
  layout after every `monitoradded` burst. The pipe assignment survives the
  reconnect (aquamarine hands `DP-4` the first free CRTC again, which is C), so
  240 comes straight back in full mode.
- **Dropped as Polaris-only** (all removable in one commit if the 580 ever comes
  back): `hardware.amdgpu.initrd.enable`, `amdgpu.runpm=0`,
  `amdgpu.gpu_recovery=1`, the `s2idle` pin and `SuspendState=freeze`, the
  greeter `monitors.xml` purge (`teonix-greeter-unpin`), and the `g9-edid.nix`
  override (kept in the tree, import commented out in `flake.nix`; only useful to
  change which mode the panel calls *preferred*).
- **Never re-probe a connector under a running compositor.** Applying an EDID
  override live via `nixos-rebuild switch` is what first produced the zoomed
  picture in Hyprland; the mode list changed under it and it re-committed to the
  new preferred mode.

Still to do on the Arc: **suspend once with an SSH session open** — sleep is
back on the kernel default (deep S3), which the 580 could not survive; nothing
says the Arc can't, but confirm it before trusting it unattended.

Unchanged by any swap: the `desc:` monitor rules (port- and card-agnostic) and
`gpu-guard.nix`. The ROCm ICDs in `modules/hardware/hardware-x86.nix` are shared
with `nixbox` and stay.

## Compositor core (2026-09-22)

### The problem

Hyprland composites every output from **one thread**. Each vblank on each output
is one full pass — damage tracking, blur, borders, the borderangle loop on the
active window — so three outputs at 120+75+60 Hz are ~255 passes/s before any
client draws anything, and every visible client that redraws (Chrome, the IDE,
Electron, Quickshell) adds its commits on top. Measured with `hypr-perf` on a busy
desktop: **60-90% of a 3 GHz Broadwell core, ~700 wakeups/s, most of it in the
kernel** (the GPU's ioctls) — and the scheduler was running that thread on **CPU
23/48, the socket without the Arc**. Pausing every client except the IDE dropped it
to 10%, so no single knob (VFR, render scheduling, animations) moves it: it is
per-frame work × frames. When that thread is preempted, migrated across sockets,
or has to wait for a core to leave C6 (133 µs here), a frame is late and the cursor
visibly stutters, which is what a 240 Hz panel makes obvious.

### The shape of the fix

Make that one thread never wait for anything, and stop rendering frames nobody
sees.

**Frames** (`hyprland.lua`, live via `hyprctl reload`):

- ASUS VG245 pinned to `1920x1080@60` instead of `preferred` (75). 15 passes/s
  for a side panel. `display-safe.sh` enforces the same for every secondary via
  `TEONIX_SECONDARY_REFRESH_CAP` (default 60; not a bandwidth limit, a compositor
  budget) so `follow`/`ultrawide` do not put it back to 75.
- `render:direct_scanout = 1`: a fullscreen window is scanned out from its own
  buffer; that output costs the compositor nothing while fullscreen.
- `cursor:no_hardware_cursors = 0`, explicit: the cursor rides the hardware plane
  and never falls back to a render.
- `animation = borderangle ... loop` on the active window is **left alone**, on
  purpose.

**A core of its own** (`compositor-core.nix`, needs one reboot):

- CPUs **2 and 30** — one physical core and its hyperthread, both on NUMA node 0
  (`0-13,28-41`), the Arc's socket. `thread_siblings_list` and
  `node0/cpulist` are the facts to re-check if the CPUs are ever changed.
- Kernel: `isolcpus=domain,managed_irq,2,30 nohz_full=2,30 rcu_nocbs=2,30
  irqaffinity=0-1,3-29,31-55 preempt=full`. The pair leaves the scheduler
  domains (nothing lands there without explicit affinity), gets no tick and no RCU
  callbacks while a single task runs, and no device interrupt defaults to it. The
  `PREEMPT_DYNAMIC` kernel is switched to full preemption for the shortest
  wakeup-to-run latency of the `SCHED_RR` compositor thread.
- `teonix-compositor-core` (oneshot at boot, re-run by `resumeCommands`):
  `performance` governor on `policy2`/`policy30` only, C6 disabled on both
  (C1/C1E/C3 stay), and the GPU's IRQ (`i915` by name in `/proc/interrupts`, IRQ 44
  today) moved to CPU 30 so vblank / flip-done completes on the render thread's
  own sibling. The rest of the chip keeps its power management.
- Manager default affinity: PID 1 and every user manager run with
  `CPUAffinity=0-1,3-29,31-55` (`systemd.settings.Manager`,
  `systemd.user.settings.Manager`), so every process they fork starts off the
  core. The compositor unit's own `CPUAffinity=` overrides it. See "The core was
  leaking" below for why `isolcpus` alone did not do this.
- cgroup cpusets, so nothing else can *ever* run there even if it inherits the
  compositor's affinity: `system.slice` (daemons) and the user manager's
  `app.slice` + `background.slice` + `user.slice` (rootless docker scopes) get
  `AllowedCPUs=0-1,3-29,31-55`, and so does every service sharing `session.slice`
  with the compositor (pipewire, pipewire-pulse, wireplumber, the xdg portals,
  dbus, gvfs, at-spi). A cpuset overrides inherited affinity, which is the point.
  `session.slice` itself stays unrestricted — the compositor is in it and a child
  cpuset cannot exceed its parent. `user@.service` needs `Delegate=… cpuset` for
  the user slices to get the controller at all; the drop-in adds it.
- The compositor unit, `wayland-wm@hyprland.desktop.service` (named after the session entry UWSM is started with), gets `CPUAffinity=2 30`,
  `NUMAPolicy=bind`, `NUMAMask=0` (memory local to the GPU's socket).

### UWSM is required

The pin lives on a systemd unit, so Hyprland must *be* one: pick **"Hyprland
(UWSM)"** in GDM (`programs.hyprland.withUWSM` in `modules/apps/programs.nix`;
plain "Hyprland" is still installed). Under UWSM the compositor runs in
`session.slice`, and `hyprland.lua` launches every long-lived child through
`uwsm app --` (`-s b` for background daemons), which hands it to `systemd-run` as
its own scope under `app-graphical.slice`/`background-graphical.slice` — the
restricted cpusets — instead of leaving it a child of the compositor stuck on CPUs
2/30. `uwsm app` is `systemd-run` underneath and works in the plain session too.
The old `dbus-update-activation-environment` / `import-environment` /
`nixos-fake-graphical-session.target` lines are gone: UWSM owns
`graphical-session.target`, and Hyprland exports its own variables.

Pitfall met on the first try (2026-09-22): NixOS adds its default unit PATH
(coreutils, findutils, grep, sed, systemd) as `Environment=PATH=` to *every*
`systemd.services`/`systemd.user.services` entry, drop-ins included. On the unit
that overrides the manager environment UWSM's env preloader had just set up, so
`start-hyprland`'s `execvp("Hyprland")` found nothing, the unit failed with result
`protocol`, and GDM bounced back to the greeter. Both drop-ins in
`compositor-core.nix` set `enableDefaultPath = false` for this reason.

### The core was leaking (2026-09-22, later the same day)

With Steam up the desktop stuttered on every window spawn and a windowed WoW fell
to 30 fps. Not the GPU (render engine ~20% for the game, ~50% total) — the
reserved core was full of other people's threads. `isolcpus=domain` only takes
2,30 out of load balancing; **it does not stop a task from being placed there**,
and once there, nothing ever moves it off. Three leaks, all measured:

1. **Inheritance from the compositor.** `CPUAffinity=2 30` on the unit is
   inherited by everything Hyprland forks. `uwsm app` children get rescued by
   their scope's cpuset — but Xwayland, wl-copy's clipboard server and anything
   exec'd bare stay in the compositor's cgroup, pinned to 2,30 for the session.
   Steam is the only X11 client here, so Xwayland went from idle to presenting
   every Steam/WoW frame from the render thread's own core the moment Steam
   started. That is why "it began when I launched Steam".
2. **Every bind spawn.** Hyprland forks on the render thread, then `sh -c` ->
   `bash` -> `uwsm app` (a Python program, ~150 ms of CPU to start) all ran
   pinned to 2,30 until `systemd-run` finally moved the app into its scope. A
   Python interpreter booting next to the render thread, on every window.
3. **Full-mask squatters.** Tasks with mask `0-55` forked or woken on CPU 2 stay
   there: `pipewire-pulse` at 12% (Steam is a Pulse client), Erlang/tokio/node
   threads from rootless-docker scopes under the user manager's `user.slice`,
   which had no cpuset at all; `session.slice` services had none either.

Fixes, one per leak, all in place now:

- `hyprland.lua` `spawn()`: every `exec()`/`run()` command is prefixed with
  `taskset -c <housekeeping>`, housekeeping being `present` minus
  `/sys/devices/system/cpu/isolated` (computed in Lua at config load; empty on a
  host without isolation, so commands run bare there). `taskset` execs straight
  into the command, so only Hyprland's fork + `sh -c` still touch the core.
  Consequence: a command is *one program + args*. `VAR=x prog`, `a && b` and
  `a | b` are shell syntax taskset cannot exec — those binds use `env …` or
  `sh -c '…'`.
- `scripts/core-fence.sh` (started first in `hyprland.start`, under
  `uwsm app -s b`): every 5 s, any thread in the compositor's cgroup that is not
  a Hyprland thread and whose mask touches an isolated CPU is `taskset` off to
  housekeeping. Catches Xwayland (also after a respawn), wl-copy, bare children.
  Logs a line per move to the scope's journal
  (`journalctl --user -t bash -g core-fence`, or `journalctl --user
  _SYSTEMD_UNIT=app-core-fence*`).
- Manager default affinity + the extra cpusets listed above, so nothing under
  either manager can be forked onto or drift onto 2,30 any more. Takes effect at
  the next login / reboot; the two script-side fixes apply on `hyprctl reload`.

Check: `hypr-perf 10 2,30` must say `intruders none on cpus 2,30`, and
`grep Cpus_allowed_list /proc/$(pidof Xwayland)/status` must not read `2,30`.

### 120 Hz is the everyday mode (2026-09-22, evening)

With the core sealed and nothing else on it, the cursor still did not feel fully
smooth at 5120x1440@240. Measured while the mouse moved (1000 Hz mouse, ~400-1000
reports/s): render thread **88% cpu, 81% of it sys, ~4 ms per wakeup** — the
thread spends whole frames inside i915, in the commit path of the two-pipe
bigjoiner mode. Idle it is ~19%. That is a driver cost, not something the
compositor or the core can fix, so the Arc's budget in `gpu.nix` is now
`px=900`: single-pipe modes only, i.e. 5120x1440@120 (Super+S, the startup mode
in `hyprland.lua`, `follow` after PIP) or 2560x1440@240 (Super+D). Super+Ctrl+S
requests 240 with a 2000 budget for when you want it anyway; Super+S returns.
The greeter was already pinned to 120. To make 240 the default again: `px=2000`
in `gpu.nix` and `5120x1440@240` in `hyprland.lua`.

### The Steam stutter is the 256 MiB BAR (2026-09-23)

The complaint that survived the core: the desktop is fluid until Steam is up
(Steam, Battle.net and WoW Classic, all Xwayland), then stutters — worst at
5120x1440@240, but present at 120 as well. With the core verified leak-free the
render thread still looked like this with that load on screen:

```
  render thread   79.7% cpu  (user 6.5%  sys 73.2%)   183 wakeups/s   ~4.36 ms cpu per wakeup   @240
  render thread   89.5% cpu  (user 7.5%  sys 82.0%)   186 wakeups/s   ~4.81 ms cpu per wakeup   @120
```

One wakeup per frame, and each wakeup spent ~4 ms *inside the kernel*. That is
not compositing work (user is 7 %) and it is not the game's frame rate: pausing
WoW (`kill -STOP`), pausing Battle.net, pausing both, a software cursor,
`direct_scanout = false` — none of it moved the number. The drivers of that
kernel time were the mode (5120 wide) and the presence of the Steam clients'
buffers, not what those clients were doing.

A false lead, recorded so it is not chased again. Toggling
`render:new_render_scheduling` live looked like the answer, three times in a
row at both refresh rates:

```
  render:new_render_scheduling = false   80.3% cpu  (user 6.6%  sys 73.7%)   167 wakeups/s   ~4.81 ms
  render:new_render_scheduling = true    17.3% cpu  (user 13.9%  sys 3.4%)  1236 wakeups/s   ~0.14 ms
```

But while it was on, the G9 picture froze, and it came back when the option
was turned off. The new scheduler (`src/output/MonitorFrameScheduler.cpp`)
hands the render fence fd to the event loop and only renders the next frame
once it has fired; if that fence never signals the monitor simply stops being
rendered. So the "cheap" number is most likely the cost of *not drawing the
ultrawide* at all — it measures nothing about the stutter. The option stays
off. If it is ever re-tried, do it with someone watching the G9.

The profile settled it. Hyprland runs setcap and is non-dumpable, so this
needs root (kernel-matched `perf` built with
`nix build .#nixosConfigurations.mainframe.config.boot.kernelPackages.perf --out-link /tmp/perf-result`):

```
sudo /tmp/perf-result/bin/perf record -t $(pgrep -f '(^|/)Hyprland( |$)' | head -1) -g -o /tmp/hypr.perf -- sleep 10
sudo chown teodor /tmp/hypr.perf
```

`kptr_restrict=1` hides kernel symbols from an unprivileged `perf report`, so
either run the report with sudo or build a kallsyms file: shift the booted
kernel's `System.map` (`$(dirname $(readlink -f /run/booted-system/kernel))/System.map`)
by the KASLR slide (`perf script --show-mmap-events | grep kallsyms` gives the
live `_text`; System.map's is `ffffffff81000000`), append `nm -n` of the
`.ko` modules at the bases the same mmap events list, and pass
`--kallsyms=`. Do the arithmetic in Python, not awk — awk doubles round these
addresses. 10 s of Steam + WoW + Battle.net on screen at 240 Hz, 30 753 samples,
inclusive:

```
  98.0%  IHyprRenderer::renderMonitor
  89.7%    commitPendingAndDoExplicitSync -> drmModeAtomicCommit
  88.8%      drm_mode_atomic_ioctl -> intel_atomic_commit -> drm_atomic_helper_prepare_planes
  88.2%        intel_plane_pin_fb -> __i915_ttm_migrate -> ttm_bo_validate -> ttm_bo_alloc_resource
  80.7%          ttm_lru_walk_for_evict -> ttm_bo_evict -> ttm_bo_handle_move_mem -> i915_ttm_move
  77.5%            i915_ttm_tt_populate -> shmem_sg_alloc_table -> shmem_alloc_and_add_folio
  28.3%              clear_page_erms          (self)
   ~15%              memcg charge, page allocator, LRU bookkeeping (self, summed)
   2.3%            emit_pte                   (the blit of the evicted object to system memory)
   2.6%    i915_gem_execbuffer2_ioctl         (the actual rendering, for scale)
```

Read bottom-up: on *every* atomic commit, pinning the framebuffer for the
display plane (`intel_plane_pin_fb`) has to migrate it into local memory, there
is no room, so TTM walks the LRU and evicts someone else's object out of VRAM
into system memory — which means allocating and zeroing fresh shmem pages for
it (`clear_page_erms`, a quarter of the whole thread) and blitting it across.
Next frame the evicted object is wanted again and the dance repeats. That is
the ~4 ms of `sys` per frame, and it is why nothing on the compositor side
moved it: the render itself is 2.6 %.

Why "no room" on an 8 GiB card: the BAR. i915 tries to resize BAR 2 to 8 GiB at
probe and the firmware-sized root-port window is too small:

```
i915 0000:07:00.0: BAR 2 [mem size 0x200000000 64bit pref]: can't assign; no space
i915 0000:07:00.0: Failed to resize BAR2 to 8192M (-ENOSPC)
i915 0000:07:00.0: Using a reduced BAR size of 256MiB
```

On a small-BAR i915 only 256 MiB of VRAM is CPU-visible, and every object
that is not flagged GPU-only — display framebuffers are pinned through the
non-GPU-only path — has to be placed inside that 256 MiB
(`i915_ttm_place_from_region` caps `lpfn` at `io_size`). A 5120x1440 swapchain
is 3 x 29.5 MiB, the two 1080p ones add 3 x 8 MiB each, and Steam, Battle.net
and WoW bring their own CPU-visible buffers into the same window. Without
Steam it fits; with Steam the window is oversubscribed and the framebuffer pin
thrashes it every frame. That is the whole pattern: only with Steam up, only
when the ultrawide is in its full mode (PIP is 2560x1440, half the buffer),
worse at 240 because it happens per frame, and independent of what the games
are doing because it is their *memory*, not their frame rate.

Closing Netflix (hardware decode in Brave, even on a 1080p output) dropped the
same session from 70 % cpu / 59 % sys to 21 % / 5 % sys with Steam, WoW and
Battle.net still up. Decode buffers are not placed "on" a monitor; VA-API
frames are CPU-visible and share the 256 MiB window with the G9 framebuffers.
The tab was the thing forcing a full composite every frame into a window that
was already full. Software decode would only stop the video buffers; the pin
and eviction above still happen at 240 Hz whenever the window overflows.

Above 4G is confirmed and is not the missing piece: the window is already at
`0x33fe0000000`. It is 256 MiB wide because the BIOS never sizes an 8 GiB
prefetch aperture. `pci=realloc` was booted 2026-09-23 and still failed, with
the root port itself refusing the window (`pcieport 0000:05:00.0: bridge
window [mem size 0x200000000 64bit pref]: can't assign; no space`) because
realloc keeps trusting the ACPI host-bridge maps, which have no 8 GiB hole.

`pci=realloc,nocrs` was booted at 01:28 the same night. The kernel logged
`PCI: Ignoring host bridge windows from ACPI` and ignored
`mem 0x30000000000-0x33fffffffff`. Region 2 stayed 256 MiB, and i915 logged
`Can't resize LMEM BAR - platform support is missing` instead of the ENOSPC
line. That string is `i915_resize_lmem_bar` failing to find a 64-bit root-bus
window above 4 GB, which `nocrs` had removed, so the resize was never
attempted. Both parameters are dropped. The NixOS wiki's Arc userspace
(`intel-media-driver`, `vpl-gpu-rt`, `LIBVA_DRIVER_NAME=iHD`,
`i915.enable_guc=3`) does not size this window. An 8 GiB BAR on this BIOS has
to be assigned from UEFI before Linux. Until then the limit is PIP, or fewer
outputs, while hardware-decoded video is playing.

### Reading `hypr-perf`

`~/.local/bin/hypr-perf [seconds] [isolated-cpus]` samples the render thread from
`/proc` (no root) and prints one block:

```
  render thread   61.4% cpu  (user 12.6%  sys 48.8%)   918 wakeups/s   ~0.67 ms cpu per wakeup
  scheduling      RR rtprio 1 nice -   allowed cpus 0-55
  ran on          cpu48:38
  gpu irq         1279/s   irq44->0-13,28-41
  monitor         DP-1   1920x1080@60
  ...
```

Before the core: `allowed cpus 0-55`, `ran on` wanders, often to socket 1. After
the reboot into the UWSM session it should read `allowed cpus 2,30`, `ran on
cpu2:… cpu30:…` only, `reserved cpus cpu2:performance/C6off=1 …`,
`irq44->30`, and `intruders none on cpus 2,30` (that line lists any non-Hyprland
thread caught on the reserved CPUs, with the cpuset or affinity that leaked it).
The busy % is workload-dependent — compare like with like — but the thing that
matters is not the average, it is that under load the cursor stays smooth while
Netflix, Chrome and the IDE all redraw.

Baseline 2026-09-22, G9 in PIP (2560x1440@120), busy desktop: 61-71% cpu, 690-920
wakeups/s, 49-62% of it *sys*, running on CPUs 23/30/44/48.

### Rollback

Pick plain "Hyprland" in GDM: everything still works, the isolated core simply
idles (isolation is a kernel parameter, so it stays reserved until the previous
generation is booted). To undo fully, drop `compositor-core.nix` from the host
list in `flake.nix` and rebuild.

## Quick checks

```bash
hypr-perf 20                                  # render thread: cpu %, where it ran, irq, intruders
cat /proc/irq/44/smp_affinity_list            # GPU irq -> 30 (number: grep i915 /proc/interrupts)
cat /sys/devices/system/cpu/cpu2/cpufreq/scaling_governor   # performance
systemd-cgls --user | less                    # apps under app-graphical.slice, not the compositor unit
cat /sys/fs/cgroup/user.slice/user-1000.slice/user@1000.service/app.slice/cpuset.cpus.effective  # no 2,30
grep Cpus_allowed_list /proc/$(pidof Xwayland)/status   # not 2,30 (core-fence.sh moved it)
ps -eLo pid=,comm=,psr= | awk '$3==2||$3==30' | grep -v Hypr   # only kernel per-cpu threads
hyprctl getoption render:new_render_scheduling   # false — on, it froze the G9 (2026-09-23)
lspci -vs 07:00.0 | grep Region               # Region 2 is 256M until UEFI grows it; 8G means ReBAR took
journalctl -k -b | grep -c 'reduced BAR'      # 0 after the fix
cat /sys/power/mem_sleep                      # kernel default since 2026-09-21: s2idle [deep]
systemctl status gpu-resume-guard gpu-boot-guard
systemctl status teonix-gpu-profile           # which card, which budgets
cat /run/teonix/display-bandwidth.conf        # budgets in force this boot
systemctl status teonix-storage-health        # loud if NVMe error counters grew
lspci -nn | grep -iE ' vga | display '        # is the card even on the bus?
ls -l /sys/class/drm/card*/device/driver      # driver actually bound?
for f in /sys/class/drm/card*-*/enabled; do echo "$f $(cat $f)"; done
~/.config/hypr/scripts/display-safe.sh safe   # recover a bad layout by hand
```
