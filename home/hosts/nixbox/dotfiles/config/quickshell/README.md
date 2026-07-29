# nixbox Quickshell rice

Primary Hyprland shell on **nixbox**: top bar, bottom dock, notifications, power menu, and BusChain Control mixer panel.

## Run / reload

```bash
# Prefer live tree while iterating (also linked via HM out-of-store symlink)
pkill waybar swaync nwg-dock-hyprland 2>/dev/null
pkill quickshell 2>/dev/null
qs -p ~/teonix/home/hosts/nixbox/dotfiles/config/quickshell &

qs -r                      # hot-reload after edits
qs ipc call mixer toggle
qs ipc call power toggle   # Super+O
qs ipc call notifs toggle
```

After `updatehome`, `~/.config/quickshell` is an out-of-store symlink to this tree — plain `quickshell` / `qs` works.

## Layout

| File | Role |
|------|------|
| `theme.js` | Shared colors / spacing (importable from subdirs) |
| `Globals.qml` | Overlay open state + BusChain helper paths |
| `Bar.qml` | Top bar |
| `Dock.qml` | Bottom dock |
| `MixerPanel.qml` | BusChain HW / apps / tracks / favorites |
| `NotificationCenter.qml` | Toasts + drawer |
| `PowerMenu.qml` | Lock / logout / suspend / reboot / shutdown |
| `components/` | Sliders, workspaces, clock, window title |

## Volume

- Scroll / status → `scripts/qs-buschain-waybar.sh` (BusChain helper, else `pactl`)
- Click → mixer panel
- Mixer ctl → `scripts/qs-buschain-ctl.sh` (needs `buschain-ctl` from `~/Projects/buschain-control`)

## Fallback

If QS is down: `buschain-control --popup` (egui). GTK mixer is legacy.
