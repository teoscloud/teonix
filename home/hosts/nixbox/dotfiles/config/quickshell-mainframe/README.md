# White Mainframe Quickshell

Sibling of the glass rice at `../quickshell/`. Opt-in; does **not** replace `~/.config/quickshell` until you switch.

## Run

```bash
qsmainframe    # kill any QS, start mainframe + square Hyprland / popin 55%
qsglass        # kill any QS, restore glass + rounded windows
qstheme        # toggle light ↔ dark palette (IPC)
```

Or:

```bash
pkill -x quickshell; qs -p ~/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe -d
```

`qsmainframe` / `qsglass` always replace the running Quickshell — they never stack a second bar/dock.

## Layout

```
TOP:  ◆WS02 ⟋ ◸01 title ◸02 title  …       ⟋ ◆LINK │ HOST │ ⌂clock⌃
                    ▔▔▔▔ marker slides
BOTTOM: ❄ ⋮⟋      ⯃  ⯃  ⟨⯃ active⟩  ⯃      ⟋ tray │ vol │ NTF
```

Every zone is a cut polygon; the side zones **wedge** into the centre so the
bars read as one milled plate rather than stacked boxes.

- **Top left cap** — focused workspace readout (`WS02`) + tick rule.
- **Top tabs** — clients on the focused workspace, ordered by real Hyprland
  scrolling-layout position (columns left→right, stacks top→bottom, floats
  last). Tabs are square with the top-left corner sliced off. Idle tabs sit
  `moduleInset` lower; the focused tab stands proud with accent stroke and
  reticle corners (skipping the sliced corner). One accent marker with tick
  caps slides along the row to the focused tab.
- **Top right** — wedged status cluster: LINK · HOST · chamfered clock.
- **Bottom left** — wedged start block (`❄` → StartMenu).
- **Bottom centre** — octagonal workspace cells inside one octagonal frame.
  **Workspace interaction only**: click a cell or scroll the rail to switch.
  Empty workspace = lone octagon dot.
- **Bottom right** — wedged tray → BusChain volume → NTF (oct count badge).

Selection is **one marker per strip**, not per cell: `SelectPill` slides and
resizes onto the focused workspace cell (`OutBack` on x, `OutCubic` on width)
with an arrival flare on its edges, and the top bar does the same with a thin
accent rail. Cells therefore keep a constant width — nothing reflows under the
marker while it travels — and the marker survives the delegate churn that
Hyprland events cause. Modules are parted by straight `VRule` hairlines with
tick caps; there are no parallelogram separators or selectors left.

Bar interaction never warps the pointer: `Globals.dispatchKeepCursor()` saves
`hyprctl cursorpos`, dispatches, then restores it.

Overlays (launcher, emoji, notif drawer, power, menus) open TL→BR from mid scale via `MainframeReveal`.

## Theme system

| Path | Role |
|------|------|
| `Theme.qml` | Singleton — palette, tokens, shared shine clock |
| `theme/tokens-light.js` / `tokens-dark.js` | Color + motion packs |
| `theme/registry.js` | Add new palettes here |
| `theme/geometry.js` | Sizes, angles, motion (not colors) |
| `components/MfShape.qml` | **Angular primitive** — `oct` / `sliceTL` / `para` / `hex` / `slantL` / `slantR` / `chamfer` / `rect`, vector-backed so cuts animate |
| `components/SelectPill.qml` | Shared sliding selection marker: double outline, edge flare, scan sweep |
| `components/OctPill.qml` | Octagonal workspace cell — content, hover hint, input |
| `components/AngularTab.qml` | Top-bar window tab — square, top-left corner sliced |
| `components/VRule.qml` | Straight module divider with tick caps |
| `components/TickRule.qml` | Measurement-tick rice detail |
| `components/CornerBrackets.qml` | Reticle corners for focused modules |
| `components/MainframeSurface.qml` | Animated diagonal shine panels |
| `components/MainframeReveal.qml` | TL→BR expand open/close |
| `components/MainframeMenu.qml` | Themed right-click menus |
| `components/HatchBand.qml` | Diagonal hatch stripes |

Geometry is one scale: change `barHeight` / `railHeight` in `theme/geometry.js`
and every inset, icon, hatch and font follows. Angles come from `octCut`,
`tabSlice`, `chamfer` and `wedge`; motion from `animFast`, `animMed`,
`animSpring`.

### Icons follow the palette

Qt resolves themed tray icons through the *system* icon theme, which is dark on
this host — those glyphs are near-white and vanish on the light palette. Each
pack therefore names its own `iconTheme` (`WhiteSur-light` / `WhiteSur-dark`),
`scripts/resolve-icons.py` resolves icon names to absolute paths inside it, and
`Globals.trayIconSource()` caches the result per theme.

Apps that publish a fixed tray *pixmap* instead of an icon name (Mailspring,
Chrome, Signal…) draw it for dark panels. On the light palette their tray id is
mapped to the icon theme's own app icon when it has one; the dark palette keeps
the app's pixmap.

**Add a color palette:** copy `tokens-light.js` → `tokens-amber.js`, register in `registry.js`, call `Theme.setPalette("amber")`.

Persist palette: `~/.config/qs-mainframe-theme` (`light`, `dark`, or `motion=off`).

IPC: `qs ipc call theme toggle` / `qs ipc call theme set dark`

## Hyprland

- `../../hypr/mainframe-decoration.conf` — `rounding = 0`, popin 55%, no soft shadow/blur
- `../../hypr/glass-decoration.conf` — restore glass rounding
- Applied via `qsmainframe` / `qsglass` (`hyprctl keyword`)

Stock Hyprland has no chamfer API. Mainframe forces square corners + angular borders (paper-fold dog-ears as border-region marks if a plugin is added later).

## Fonts

Share Tech Mono (vendored OFL) + IBM Plex Mono. Rebuild after first pull: `systemupdate` / `nixupgrade`.

## Mockup

See `mockup/white-mainframe.png` for geometry reference.
