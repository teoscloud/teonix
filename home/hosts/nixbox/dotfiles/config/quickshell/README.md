# nixbox Quickshell rice

Primary Hyprland shell: top bar, bottom dock, Control Center (media + notifications),
Spotlight launcher, emoji picker, BusChain mixer, power menu.

## Home Manager (reproducible)

Wired from `home/hosts/nixbox/modules/dotfiles.nix` (imported by `home/nixbox.nix`):

| Path | HM |
|------|-----|
| `~/.config/quickshell` | Out-of-store symlink → this tree (`mkOutOfStoreSymlink`) so edits hot-reload without rebuild |
| `~/.config/hypr/hyprland.conf` | Store copy — blur layerrules, Super+Space / Super+Period binds, BusChain QS env |
| Packages | `quickshell`, `libqalculate` (`qalc`), `ffmpeg` (wallpaper tint), `wl-clipboard`, `wtype`, `gnome-calculator` |
| Session env | `BUSCHAIN_CONTROL_QS_MIXER=1`, `BUSCHAIN_CONTROL_QS_STRIP=1` in `home/nixbox.nix` |

Fresh machine:

```bash
# clone repo to ~/teonix, then
updatehome          # applies HM symlink + hypr conf + session env
# system rebuild if packages changed
qs -p ~/.config/quickshell
```

## BusChain mixer + scroll strip

Contract: `~/Projects/buschain-control/docs/HANDOVER-QUICKSHELL.md`

| Piece | Role |
|-------|------|
| `VolumePill.qml` | Bar HW % / mute; click opens mixer; wheel = ±5% notches (max 2) |
| `ScrollStrip.qml` | Transparent hit target over pill (`exclusiveZone: -1`); same wheel/click |
| `MixerPanel.qml` | Frost glass panel — tabs Playback · Tracks · Output · Input |
| `scripts/qs-mixer-toggle.sh` | Tray / `popup playback` bridge → `qs ipc call mixer toggle` |
| `scripts/qs-buschain-ctl.sh` | Resolves `buschain-ctl` |
| `scripts/qs-buschain-waybar.sh` | Status for pill (falls back to pactl) |

```bash
qs ipc call mixer toggle
# Env (also set via Hyprland + HM sessionVariables):
# BUSCHAIN_CONTROL_QS_MIXER=1
# BUSCHAIN_CONTROL_QS_STRIP=1
```

Poll: `buschain-ctl mixer` while open (~180 ms) + wake on `$XDG_RUNTIME_DIR/buschain-control/mixer.tick`.
Favorites: `~/.config/buschain-control/mixer-pins.json`.

Scroll geometry (Hyprland `env`):

| Env | Default (nixbox) |
|-----|------------------|
| `BUSCHAIN_CONTROL_SCROLL_ANCHOR` | `right` |
| `BUSCHAIN_CONTROL_SCROLL_MARGIN_X` | `200` (over bar volume pill; tune if miss) |
| `BUSCHAIN_CONTROL_SCROLL_WIDTH` / `_HEIGHT` | `110` / `38` |

Handover parity checklist:

- [x] Tabs Playback · Tracks · Output · Input
- [x] Master HW 0–100% + mute; wheel notches ≤2×5%; absolute drag set
- [x] Favorited tracks + app streams on Playback; star ↔ `mixer-pins.json`
- [x] Tracks: dB gain (−48…+12 via UI 0–150), mute
- [x] Output/Input: sinks/sources; Default ≠ Master HW labels
- [x] Esc / click-away; `qs ipc call mixer toggle`
- [x] Poll + `mixer.tick` wake
- [x] Transparent scroll strip (`exclusiveZone: -1`), click opens mixer
- [x] `BUSCHAIN_CONTROL_QS_MIXER=1` + `QS_STRIP=1` (Hyprland + HM sessionVariables)
- [x] Toggle script at `scripts/qs-mixer-toggle.sh`

## Run / reload

```bash
pkill -x quickshell 2>/dev/null
qs -p ~/.config/quickshell &

qs -r                              # hot-reload after .qml edits
# theme.js / new files need a full restart

qs ipc call launcher toggle        # Super+Space
qs ipc call emoji toggle           # Super+Period
qs ipc call notifs toggle
qs ipc call mixer toggle
qs ipc call power toggle
```

## Layout

Bar + dock render **only on `DP-1`** (`Globals.shellMonitor`). Overlays follow focus.

| Zone | Modules |
|------|---------|
| Left | Active window pill |
| Center | Workspaces |
| Right | Notifs · Power · **Vol pill** · Tray · Clock |
| Bottom | Dock |
| Overlay | Spotlight · Emoji · Control Center · **Mixer** · Power |
| Strip | Transparent HW scroll over vol pill |

## Theme

`theme.js` — FiraCode Mono, glass alphas (bar/dock untinted; overlays use wallpaper tint via `Globals.glassColor`).
Hyprland frost: `layerrule = blur on, … match:namespace ^(quickshell.*)$` with `ignore_alpha 0.08`.
Wallpaper tint: `scripts/qs-wallpaper-tint.py` → `~/.cache/qs-wallpaper-tint.json`.
