# nixbox Quickshell rice

Primary Hyprland shell: top bar, bottom dock, Control Center (media + notifications),
Spotlight launcher, emoji picker, power menu.

## Home Manager (reproducible)

Wired from `home/hosts/nixbox/modules/dotfiles.nix` (imported by `home/nixbox.nix`):

| Path | HM |
|------|-----|
| `~/.config/quickshell` | Out-of-store symlink → this tree (`mkOutOfStoreSymlink`) so edits hot-reload without rebuild |
| `~/.config/hypr/hyprland.conf` | Store copy — blur layerrules, Super+Space / Super+Period binds |
| Packages | `quickshell`, `libqalculate` (`qalc`), `ffmpeg` (wallpaper tint), `wl-clipboard`, `wtype` in `modules/apps/packages.nix` |

Fresh machine:

```bash
# clone repo to ~/teonix, then
updatehome          # applies HM symlink + hypr conf
# system rebuild if packages changed (libqalculate / ffmpeg)
qs -p ~/.config/quickshell
```

Wallpaper glass tint: `scripts/qs-wallpaper-tint.py` (samples active hyprpaper via ffmpeg).
Cache: `~/.cache/qs-wallpaper-tint.json`.

## Run / reload

```bash
pkill -x quickshell 2>/dev/null
qs -p ~/.config/quickshell &

qs -r                              # hot-reload after .qml edits
# theme.js / new files need a full restart

qs ipc call launcher toggle        # Super+Space
qs ipc call emoji toggle           # Super+Period
qs ipc call notifs toggle          # Super+N (if bound)
qs ipc call power toggle           # Super+O
```

## Layout

Bar + dock render **only on `DP-1`** (`Globals.shellMonitor`). Overlays follow the focused screen.

| Zone | Modules |
|------|---------|
| Left | Active window pill |
| Center | Workspaces |
| Right | Notifs · Power · Tray · Clock |
| Bottom | Dock (pinned + running extras) |
| Overlay | Spotlight · Emoji · Control Center · Power |

## Theme

`theme.js` — FiraCode Mono, glass alphas (bar/dock untinted; overlays use wallpaper tint via `Globals.glassColor`).
Hyprland frost: `layerrule = blur on, … match:namespace ^(quickshell.*)$` with `ignore_alpha 0.08`.
