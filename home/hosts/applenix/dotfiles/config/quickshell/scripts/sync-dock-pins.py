#!/usr/bin/env python3
"""Sync ~/.config/qs-dock-pinned → ~/.config/qs-dock-apps.json with resolved icons.

Pinned list format matches nwg-dock (~/.cache/nwg-dock-pinned): one desktop id per line.
Not managed by Home Manager — edit qs-dock-pinned freely, then re-run this script
(or let Dock.qml invoke it on load).
"""
from __future__ import annotations

import configparser
import json
import sys
from pathlib import Path

HOME = Path.home()
PINNED = HOME / ".config/qs-dock-pinned"
OUT = HOME / ".config/qs-dock-apps.json"
NWG = HOME / ".cache/nwg-dock-pinned"

SEARCH_DIRS = [
    HOME / ".local/share/applications",
    HOME / ".local/share/flatpak/exports/share/applications",
    Path("/var/lib/flatpak/exports/share/applications"),
    Path("/run/current-system/sw/share/applications"),
    HOME / ".nix-profile/share/applications",
    Path("/usr/share/applications"),
]

ICON_ROOTS = [
    HOME / ".local/share/icons",
    HOME / ".local/share/flatpak/exports/share/icons",
    Path("/var/lib/flatpak/exports/share/icons"),
    Path("/run/current-system/sw/share/icons"),
    HOME / ".icons",
    Path("/usr/share/icons"),
    Path("/run/current-system/sw/share/pixmaps"),
    Path("/usr/share/pixmaps"),
]

# Prefer the active GTK theme first (WhiteSur-dark on nixbox).
THEMES = [
    "WhiteSur-dark",
    "WhiteSur",
    "WhiteSur-light",
    "hicolor",
    "Adwaita",
    "breeze",
    "breeze-dark",
    "Papirus",
    "Papirus-Dark",
]

SIZES = [
    "scalable",
    "256x256",
    "128x128",
    "96x96",
    "64x64",
    "48x48",
    "32x32",
    "22x22",
]

APPDIRS = ["apps", "applications", "status", "devices", "categories", "mimetypes"]

SPECIAL = {
    "Mailspring": ["Mailspring.desktop", "mailspring.desktop"],
    "Spotify": ["spotify.desktop"],
    "Mullvad VPN": [
        "mullvad-vpn.desktop",
        "mullvad_vpn.desktop",
        "Mullvad VPN.desktop",
    ],
    "app.zen_browser.zen": [
        "app.zen_browser.zen.desktop",
        "zen.desktop",
        "zen-browser.desktop",
    ],
    "signal": ["signal.desktop", "signal-desktop.desktop"],
    "equibop": ["equibop.desktop"],
    "google-chrome": ["google-chrome.desktop"],
    "brave-browser": ["brave-browser.desktop"],
    "nemo": ["nemo.desktop"],
    "obsidian": ["obsidian.desktop"],
    "kitty": ["kitty.desktop"],
    "cursor": ["cursor.desktop"],
    "org.gnome.clocks": ["org.gnome.clocks.desktop"],
    "org.gnome.TextEditor": ["org.gnome.TextEditor.desktop"],
}


def find_desktop(name: str) -> Path | None:
    candidates: list[str] = []
    if name in SPECIAL:
        candidates.extend(SPECIAL[name])
    candidates.extend(
        [
            f"{name}.desktop",
            f"{name.lower()}.desktop",
            f"{name.replace(' ', '')}.desktop",
            f"{name.replace(' ', '-').lower()}.desktop",
            f"{name.replace(' ', '_')}.desktop",
        ]
    )
    for d in SEARCH_DIRS:
        if not d.is_dir():
            continue
        for c in candidates:
            p = d / c
            if p.is_file():
                return p
    # fuzzy fallback
    key = name.lower().replace(" ", "")
    for d in SEARCH_DIRS:
        if not d.is_dir():
            continue
        for p in d.glob("*.desktop"):
            stem = p.stem.lower().replace(" ", "")
            if key in stem or stem in key:
                return p
    return None


def _icon_names(icon: str) -> list[str]:
    names = [icon]
    if not icon.endswith((".png", ".svg", ".xpm")):
        names += [f"{icon}.png", f"{icon}.svg", f"{icon}.xpm"]
    return names


def resolve_icon_file(icon: str) -> str:
    if not icon:
        return ""
    ip = Path(icon)
    if ip.is_file():
        return str(ip)

    names = _icon_names(icon)

    for root in ICON_ROOTS:
        if not root.is_dir():
            continue
        for n in names:
            p = root / n
            if p.is_file():
                return str(p)

        # Standard Freedesktop: theme/size/context/icon
        for theme in THEMES:
            tdir = root / theme
            if not tdir.is_dir():
                continue
            for size in SIZES:
                for appdir in APPDIRS:
                    for n in names:
                        p = tdir / size / appdir / n
                        if p.is_file():
                            return str(p)

            # WhiteSur-style: theme/apps/scalable/icon (no size middle folder first)
            for appdir in APPDIRS:
                for size in SIZES:
                    for n in names:
                        p = tdir / appdir / size / n
                        if p.is_file():
                            return str(p)

    # Last resort: recursive name match under icon roots (capped)
    needle = set(names)
    for root in ICON_ROOTS:
        if not root.is_dir():
            continue
        try:
            for p in root.rglob("*"):
                if p.name in needle and p.is_file():
                    return str(p)
        except OSError:
            continue
    return ""


def parse_desktop(desk: Path, name: str) -> dict:
    entry = {
        "id": name,
        "desktopId": desk.stem,
        "label": name,
        "exec": name,
        "className": desk.stem,
        "iconName": desk.stem,
        "iconPath": "",
    }
    cp = configparser.ConfigParser(interpolation=None)
    cp.read(desk, encoding="utf-8")
    if "Desktop Entry" not in cp:
        return entry
    sec = cp["Desktop Entry"]
    entry["label"] = sec.get("Name", name)
    exec_line = sec.get("Exec", name)
    for tok in ("%f", "%F", "%u", "%U", "%i", "%c", "%k"):
        exec_line = exec_line.replace(tok, "")
    entry["exec"] = " ".join(exec_line.split())
    entry["className"] = sec.get("StartupWMClass", desk.stem)
    icon = sec.get("Icon", desk.stem)
    if icon.startswith("/"):
        entry["iconName"] = desk.stem
        entry["iconPath"] = icon if Path(icon).is_file() else ""
    else:
        entry["iconName"] = icon
        entry["iconPath"] = resolve_icon_file(icon) or resolve_icon_file(desk.stem)
    if not entry["iconPath"]:
        entry["iconPath"] = resolve_icon_file(entry["iconName"])
    return entry


def main() -> int:
    if not PINNED.exists():
        if NWG.exists():
            PINNED.write_text(NWG.read_text(encoding="utf-8"), encoding="utf-8")
            print(f"seeded {PINNED} from {NWG}", file=sys.stderr)
        else:
            print(f"missing {PINNED}", file=sys.stderr)
            return 1

    pins = [l.strip() for l in PINNED.read_text(encoding="utf-8").splitlines() if l.strip()]
    apps = []
    for name in pins:
        desk = find_desktop(name)
        if desk:
            apps.append(parse_desktop(desk, name))
        else:
            apps.append(
                {
                    "id": name,
                    "desktopId": name,
                    "label": name,
                    "exec": name,
                    "className": name,
                    "iconName": name.lower().replace(" ", "-"),
                    "iconPath": resolve_icon_file(name)
                    or resolve_icon_file(name.lower().replace(" ", "-")),
                }
            )
        a = apps[-1]
        print(
            f"{name:40} -> {(a['iconPath'] or a['iconName'])[:80]}",
            file=sys.stderr,
        )

    OUT.write_text(json.dumps(apps, indent=2) + "\n", encoding="utf-8")
    print(str(OUT))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
