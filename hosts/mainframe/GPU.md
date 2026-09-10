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

## Fact 3: the display bandwidth ceiling

The card is a Sapphire RX 580 (Polaris 10, `1002:67df`, DCE 11.2). The G9 at
`5120x1440@120` 8bpc needs about **25.4 Gbps** against DP 1.4 HBR3's **25.92 Gbps**
usable. That leaves nothing for a second pipe, so DCE 11.2 cannot validate a second
output while the G9 is at 120 Hz. It shows up as an endless

```
atomic drm request: failed to commit: Invalid argument
```

storm, or as Hyprland simply refusing the modeset and keeping the previous mode.

This is a hard ceiling, not a configuration problem. **`5120x1440@120` is banned
outright on this card** via a per-output pixel-rate budget
(`TEONIX_MAX_PIXEL_RATE_MPS=500` in `/etc/teonix/display-bandwidth.conf`): that
mode is ~885 Mpx/s, while the two sanctioned G9 modes — `2560x1440@120` (the
default) and `5120x1440@60` (`Super+S`) — are both ~442 Mpx/s and were verified
live on 2026-09-10 with two extra 1080p60 outputs attached. `display-safe.sh`
never selects a mode above the budget, for any monitor in any port. A GPU swap
drops the quirks file and with it the ban.

### The greeter is upstream of all that

`display-safe.sh` only exists once a session is running. GDM/mutter comes first
and would take the ultrawide's EDID-preferred mode — which *is* `5120x1440@120`.
The only lever mutter offers is `monitors.xml`, so `gpu-quirks-polaris.nix`
generates one and installs it in both places a modern GDM looks:

- `/etc/xdg/monitors.xml` — the global mutter default, read by the greeter's
  dynamic user.
- `/var/lib/gdm/seat0/config/monitors.xml` — GDM 49+ moved the greeter's config
  to a per-seat directory; written by `teonix-greeter-monitor-pin.service`,
  ordered before the display manager.

The per-seat file is **generated at boot** by `greeter-monitors.py` from the EDIDs
actually connected, because a mutter configuration only applies when it lists
*every* connected monitor — there is no way to pin one panel and let mutter
improvise the rest. That is what went wrong on 2026-09-10: with three monitors
attached, the static ultrawide-only pin matched nothing, mutter fell back to its
own left-to-right guess, and the greeter was laid out across the wrong geometry.

The generator names no monitor, connector or card index. For each connected
output it picks the largest mode inside the pixel-rate budget, then the refresh
nearest 60 Hz at that size — that lands on the panel's native timing instead of a
broadcast 50 Hz entry or a GTF-derived rate the kernel may not actually offer,
and a mode mutter cannot find would invalidate the whole configuration.

**The greeter gets exactly one output**, the largest panel, with every other
connected monitor listed under `<disabled>`. So an ultrawide gets its full width
with the prompt dead centre, a 1440p panel gets 1440p, the refresh ceiling
applies either way, and the rest of the desk lights up a second later when the
session starts.

### Why the greeter only drives one monitor

The first version enabled every connected output, and on 2026-09-10 that left the
login prompt on a completely black desk with all three monitors attached. Mutter
accepted the modeset and then failed *every* page flip:

```
gnome-shell[2361]: Added device '/dev/dri/card1' (amdgpu) using atomic mode setting.
gnome-shell[2361]: Page flip failed: drmModeAtomicCommit: Invalid argument   (x hundreds)
gnome-shell[2361]: Failed to post KMS update: drmModeAtomicCommit: Invalid argument
```

Unplugging the ultrawide's DisplayPort made the greeter appear on another panel;
plugging it back in after logging into Hyprland was fine. The kernel logs for
that boot and the previous one are equivalent — same card, same connectors, no
DRM errors — so this is not the card giving out. Hyprland drives those same three
outputs at those same modes without complaint, because it commits each output
separately; mutter commits all CRTCs in one atomic update, and this DCE 11.2 part
rejects the combined one.

The reason a bad layout is fatal rather than merely ugly: mutter treats a *stored*
configuration as policy and forces it, while a layout it picked itself gets
downgraded until it works. The boot before this one had the old ultrawide-only pin
that matched nothing, so mutter improvised, recovered on its own, and produced a
greeter that was merely off-centre. Handing mutter a three-output config removed
its licence to back off. One output removes the failing commit entirely.

### The greeter repairs itself

`teonix-greeter-watchdog.service` starts with the display manager, waits 25
seconds, and if the greeter is wedged it deletes the generated layout, deletes the
static `/etc/xdg` fallback for the rest of the boot, and restarts GDM once —
handing the greeter back to mutter's own logic, which downgrades until it finds
something the card will take. `teonix-greeter-monitor-pin` sees the stand-down
marker on the way back up and does not regenerate the file it just lost. A note is
left in `/run/teonix/greeter-repaired` and printed at the next interactive shell.
Both files live in `/run`, so a reboot tries the pinned layout again.

Two guards make it unable to disturb a working session: it acts only while no
session of `Class=user` exists — checked once after the wait and again immediately
before acting — and at most once per boot. The worst a false positive can cost is
one restart of a greeter nobody was using.

The trigger is the **count of page-flip failures since boot**, not the recent
rate, and that distinction matters: a black greeter goes quiet. Of the 170
failures on 2026-09-10, 57 landed in the first eight seconds and then stopped,
because a static screen has nothing to repaint — so "is it still failing right
now?" reads zero on a screen that is stone dead. Replayed against the journal, the
threshold of 25 fires on both black boots (170 and 103) and stays silent on the
healthy one (0) and the one mutter fixed by itself (6).

Manual recovery, should it ever be needed: `Ctrl+Alt+F3` to a console, then
`rm /var/lib/gdm/seat0/config/monitors.xml && systemctl restart display-manager`.
No cable needs unplugging.

`/etc/xdg/monitors.xml` remains as a static fallback for the single-ultrawide
case only. Three things about that fallback file:

- **It names the panel.** Unavoidable: mutter matches on connector plus EDID
  vendor/product/serial. It is the only such hardcoding in the repo and it is
  quarantined in the quirks file, so a GPU swap removes it. If the panel itself
  is replaced, nothing matches and mutter just falls back to its own defaults.
- **The rate must be exact.** mutter matches stored rates within 0.001 Hz, so a
  wrong value fails silently and hands the greeter back to the banned mode.
  Derive it as `pixel clock / (htotal x vtotal)` from `edid-decode`; the same
  formula reproduces mutter's own `119.999` for the 120 Hz mode, which is how the
  value was verified.
- **Only "ultrawide alone" layouts are listed**, once per connector the card can
  expose. Multi-monitor cases are handled by the generator above, not here.

Connector names move: reseating the card on 2026-09-10 swapped the ultrawide from
`DP-2` to `DP-1`. Hyprland's `desc:` rules and the generator both absorbed that
with no changes, which is exactly why neither may ever name a port.

Note that a stale `~/.config/monitors.xml` **overrides** `/etc/xdg` for a GNOME
session. This machine had one left over from January pinning the ultrawide at
`239.761` Hz. It is irrelevant under Hyprland, but delete it before ever starting
a GNOME session.

## What is in place

### System (`hosts/mainframe/`)

| File | Purpose | Survives a GPU swap? |
| --- | --- | --- |
| `gpu-quirks-polaris.nix` | Everything specific to the RX 580 | **No** — delete the import |
| `gpu-guard.nix` | Board-level no-video protection | Yes — keep it |
| `platform.nix` | Hibernate tier (`resumeDevice`, swap, `HibernateDelaySec`) | Yes |

`gpu-quirks-polaris.nix` sets:

- `hardware.amdgpu.initrd.enable` — amdgpu loads deterministically from the initrd.
  On 2026-09-10 udev coldplug silently failed to insert it (all DRM deps loaded,
  module never appeared) and the session degraded to simpledrm + llvmpipe: one fake
  `Unknown-1` output, wrong resolution, no EDID. Never load amdgpu by hand while a
  session is running on simpledrm — the takeover kills the compositor to a TTY.
- `mem_sleep_default=s2idle` and `SuspendState=freeze` — suspend still works, but
  the GPU keeps power, so the resume re-POST that wedged the card never happens.
- `amdgpu.runpm=0` — runtime D3cold is a second wedge path.
- `amdgpu.gpu_recovery=1` — attempt a reset rather than staying hung.
- `/etc/teonix/display-bandwidth.conf`, the single place both limits are defined:
  the secondary-output refresh cap and the pixel-rate budget that bans
  `5120x1440@120`. `display-safe.sh` reads it and applies **no limits at all** if
  it is absent.
- a boot service that warns loudly (journal plus a notice at login) if the fitted
  display device is no longer `1002:67df`, so these quirks cannot silently outlive
  the card they were written for.

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

## Replacing the GPU

The whole point of the split above is that this is a one-file change.

1. **Drop the quirks import.** Remove `./hosts/mainframe/gpu-quirks-polaris.nix`
   from `flake.nix`. That alone restores stock behaviour: deep S3 suspend and no
   refresh cap. Leave `gpu-guard.nix` imported — it is about the *chassis*, not the
   card, and this board still has no onboard video.
2. **Re-test suspend** with `cat /sys/power/mem_sleep` back to `s2idle [deep]`. Do
   the first test with an SSH session open from another machine.
3. **Check the refresh cap.** A DSC-capable card can drive the G9 at 120 Hz *and* a
   second output. If you keep the quirks file for other reasons, raise
   `maxRefreshMultiOutput` in it; if you drop the file, there is no cap at all and
   `share` will simply use each panel's best mode.
4. **Revisit `videoDrivers`.** `modules/services/system-services.nix:175` pins
   `[ "amdgpu" ]` for all of `x86_64-linux`. An Intel or NVIDIA card needs that
   changed. This is the one GPU assumption that lives outside the quirks file.
5. **Keep the `desc:` monitor rules.** They are port- and card-agnostic already.
6. **Re-check the primary display prefix** in `hyprland.conf` only if you also
   change monitors.

If you forget step 1, the login notice from `teonix-gpu-quirks-staleness` will tell
you: it fires whenever the fitted display device is not `1002:67df`.

## Quick checks

```bash
cat /sys/power/mem_sleep                      # expect: [s2idle] deep
systemctl status gpu-resume-guard gpu-boot-guard
systemctl status teonix-gpu-quirks-staleness  # loud if the card changed
systemctl status teonix-storage-health        # loud if NVMe error counters grew
lspci -nn | grep -i ' vga '                   # is the card even on the bus?
ls -l /sys/bus/pci/devices/*/driver | grep -i amdgpu   # driver actually bound?
for f in /sys/class/drm/card*-*/enabled; do echo "$f $(cat $f)"; done
~/.config/hypr/scripts/display-safe.sh safe   # recover a bad layout by hand
```
