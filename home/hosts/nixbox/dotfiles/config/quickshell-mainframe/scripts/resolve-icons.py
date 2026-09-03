#!/usr/bin/env python3
"""Resolve icon names to files inside one explicit icon theme.

Qt hands themed tray icons to QIcon, which resolves them through the *system*
icon theme. The shell asks for an explicit theme instead and gets absolute
paths back: Adwaita for status glyphs, hicolor for app brands.

usage: resolve-icons.py THEME MODE NAME [NAME...]
  MODE mono  status glyph — symbolic variants first
  MODE app   launcher icon — full-colour variants first
stdout: {"name": "/abs/path", "missing-name": ""}
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

HOME = Path.home()

ICON_ROOTS = [
    HOME / ".local/share/icons",
    HOME / ".icons",
    HOME / ".local/share/flatpak/exports/share/icons",
    Path("/var/lib/flatpak/exports/share/icons"),
    Path("/run/current-system/sw/share/icons"),
    Path("/usr/share/icons"),
]

PIXMAP_ROOTS = [
    Path("/run/current-system/sw/share/pixmaps"),
    Path("/usr/share/pixmaps"),
]

# App brands stay in hicolor. Mono may use WhiteSur-light/dark status ink.
# Never walk WhiteSur apps/ or Breeze.
TAIL_THEMES = {
    "mono": ["hicolor"],
    "app": ["hicolor"],
}

CATEGORIES = {
    "mono": ["status", "panel", "actions", "devices", "categories", "legacy"],
    # apps/ stays out of both: WhiteSur apps/ is the iOS restyle.
    # actions/ stays out of app: "cursor" would hit cursor-arrow.svg.
    "app": ["apps", "applications"],
}

SIZES = {
    # Symbolic dirs carry the theme's light/dark ink colour, so tray glyphs
    # take them first.
    "mono": [
        "symbolic",
        "22",
        "24",
        "32",
        "16",
        "48",
        "64",
        "scalable",
        "22x22",
        "24x24",
        "32x32",
        "16x16",
        "48x48",
        "64x64",
    ],
    "app": [
        "scalable",
        "64",
        "48",
        "32",
        "128",
        "256",
        "24",
        "22",
        "64x64",
        "48x48",
        "32x32",
        "128x128",
        "256x256",
        "symbolic",
    ],
}

EXTS = [".svg", ".png"]

STEAM_ID_RE = re.compile(
    r"steam[-_]?app[-_]?(\d+)|steam[-_]?icon[-_]?(\d+)",
    re.IGNORECASE,
)

STEAM_CACHE_ROOTS = [
    HOME / ".steam/steam/appcache/librarycache",
    HOME / ".local/share/Steam/appcache/librarycache",
    HOME / ".var/app/com.valvesoftware.Steam/data/Steam/appcache/librarycache",
    HOME / ".var/app/com.valvesoftware.Steam/.steam/steam/appcache/librarycache",
]

STEAM_USERDATA_ROOTS = [
    HOME / ".steam/steam/userdata",
    HOME / ".local/share/Steam/userdata",
    HOME / ".var/app/com.valvesoftware.Steam/data/Steam/userdata",
]

DESKTOP_ROOTS = [
    HOME / ".local/share/applications",
    HOME / ".local/share/flatpak/exports/share/applications",
    Path("/var/lib/flatpak/exports/share/applications"),
    Path("/run/current-system/sw/share/applications"),
    Path("/usr/share/applications"),
    HOME / ".steam/steam/steamapps",
    HOME / ".local/share/Steam/steamapps",
]


def theme_dirs(theme: str) -> list[Path]:
    return [root / theme for root in ICON_ROOTS if (root / theme).is_dir()]


def inherited(theme: str) -> list[str]:
    for d in theme_dirs(theme):
        index = d / "index.theme"
        if not index.is_file():
            continue
        for line in index.read_text(errors="replace").splitlines():
            if line.startswith("Inherits="):
                return [p.strip() for p in line[9:].split(",") if p.strip()]
    return []


def theme_chain(theme: str, mode: str) -> list[str]:
    chain: list[str] = []
    tail = TAIL_THEMES.get(mode, TAIL_THEMES["app"])
    for candidate in [theme, *inherited(theme), *tail]:
        if candidate and candidate not in chain:
            chain.append(candidate)
    return chain


def candidate_names(name: str, mode: str) -> list[str]:
    if name.endswith("-symbolic"):
        return [name, name[: -len("-symbolic")]]
    if mode == "mono":
        return [name + "-symbolic", name]
    return [name, name + "-symbolic"]


def find_in_theme(theme: str, name: str, mode: str) -> str:
    for base in theme_dirs(theme):
        for candidate in candidate_names(name, mode):
            for category in CATEGORIES[mode]:
                for size in SIZES[mode]:
                    for ext in EXTS:
                        for rel in (
                            base / category / size / f"{candidate}{ext}",
                            base / size / category / f"{candidate}{ext}",
                            base / category / f"{candidate}{ext}",
                        ):
                            if rel.is_file():
                                return str(rel)
    return ""


def steam_appid(name: str) -> str:
    m = STEAM_ID_RE.search(name or "")
    if not m:
        return ""
    return m.group(1) or m.group(2) or ""


def desktop_icon_name(path: Path) -> str:
    try:
        for line in path.read_text(errors="replace").splitlines():
            if line.startswith("Icon="):
                return line[5:].strip()
    except OSError:
        return ""
    return ""


def first_existing(paths: list[Path]) -> str:
    for path in paths:
        if path.is_file():
            return str(path)
    return ""


def find_steam_desktop_icon(appid: str) -> str:
    names = [
        f"steam_app_{appid}.desktop",
        f"steam-app-{appid}.desktop",
        f"steam_icon_{appid}.desktop",
    ]
    for root in DESKTOP_ROOTS:
        if not root.is_dir():
            continue
        for name in names:
            hit = root / name
            if hit.is_file():
                icon = desktop_icon_name(hit)
                if icon:
                    return icon
    return ""


def find_librarycache_icon(appid: str) -> str:
    preferred = [
        "icon.png",
        "icon.jpg",
        "icon.jpeg",
        "icon.ico",
        "logo.png",
        "logo.jpg",
        f"{appid}_icon.png",
        f"{appid}_icon.jpg",
        f"{appid}_icon.jpeg",
    ]
    for root in STEAM_CACHE_ROOTS:
        if not root.is_dir():
            continue
        folder = root / appid
        if folder.is_dir():
            hit = first_existing([folder / name for name in preferred])
            if hit:
                return hit
            extras: list[Path] = []
            try:
                extras = [p for p in folder.iterdir() if p.is_file()]
            except OSError:
                extras = []
            images: list[Path] = []
            for path in extras:
                low = path.name.lower()
                if path.suffix.lower() not in {".png", ".jpg", ".jpeg", ".ico"}:
                    continue
                if "icon" in low or "logo" in low:
                    return str(path)
                images.append(path)
            if images:
                def rank(path: Path) -> tuple[int, int]:
                    low = path.name.lower()
                    try:
                        size = path.stat().st_size
                    except OSError:
                        size = 1 << 30
                    pref = 2 if ("hero" in low or "header" in low) else 1
                    return (pref, size)

                images.sort(key=rank)
                return str(images[0])
        hit = first_existing([root / name for name in preferred if name.startswith(appid)])
        if hit:
            return hit
        try:
            for path in root.glob(f"{appid}*icon*"):
                if path.is_file() and path.suffix.lower() in {".png", ".jpg", ".jpeg", ".ico"}:
                    return str(path)
        except OSError:
            pass
    return ""


def find_steam_grid_icon(appid: str) -> str:
    # Non-Steam / Proton shortcuts live in userdata grid, not librarycache.
    names = [
        f"{appid}_icon.png",
        f"{appid}_icon.jpg",
        f"{appid}.png",
        f"{appid}.jpg",
        f"{appid}p.png",
    ]
    for root in STEAM_USERDATA_ROOTS:
        if not root.is_dir():
            continue
        try:
            users = list(root.iterdir())
        except OSError:
            continue
        for user in users:
            grid = user / "config" / "grid"
            if not grid.is_dir():
                continue
            hit = first_existing([grid / name for name in names])
            if hit:
                return hit
    return ""


def find_hicolor_steam_icon(appid: str) -> str:
    names = [f"steam_icon_{appid}.png", f"steam_app_{appid}.png"]
    sizes = ["256x256", "128x128", "64x64", "48x48", "32x32", "24x24", "16x16"]
    for root in ICON_ROOTS:
        hicolor = root / "hicolor"
        if not hicolor.is_dir():
            continue
        for size in sizes:
            for name in names:
                hit = hicolor / size / "apps" / name
                if hit.is_file():
                    return str(hit)
        for name in names:
            try:
                for hit in hicolor.glob(f"**/{name}"):
                    if hit.is_file():
                        return str(hit)
            except OSError:
                pass
    return ""


def resolve_steam_game(name: str, theme: str, mode: str) -> str:
    appid = steam_appid(name)
    if not appid:
        return ""
    for candidate in (
        f"steam_app_{appid}",
        f"steam_icon_{appid}",
        f"steam-app-{appid}",
        f"steam-icon-{appid}",
    ):
        for candidate_theme in theme_chain(theme, mode):
            hit = find_in_theme(candidate_theme, candidate, mode)
            if hit:
                return hit
        hit = find_pixmap(candidate)
        if hit:
            return hit
    desktop_icon = find_steam_desktop_icon(appid)
    if desktop_icon:
        if desktop_icon.startswith("/"):
            if Path(desktop_icon).is_file():
                return desktop_icon
        elif not steam_appid(desktop_icon):
            hit = resolve_theme_only(theme, desktop_icon, mode)
            if hit:
                return hit
    hit = find_librarycache_icon(appid)
    if hit:
        return hit
    hit = find_steam_grid_icon(appid)
    if hit:
        return hit
    return find_hicolor_steam_icon(appid)


def desktop_icon_for_name(name: str) -> str:
    """WM class is often 'spotify' while the .desktop Icon= is 'spotify-client'."""
    if not name or "/" in name:
        return ""
    stems = [name, name.lower()]
    if not name.endswith(".desktop"):
        stems += [name + ".desktop", name.lower() + ".desktop"]
    seen = set()
    for root in DESKTOP_ROOTS:
        if not root.is_dir():
            continue
        for stem in stems:
            path = root / stem
            key = str(path)
            if key in seen:
                continue
            seen.add(key)
            if path.is_file():
                icon = desktop_icon_name(path)
                if icon and icon.lower() != name.lower():
                    return icon
    return ""


def resolve_theme_only(theme: str, name: str, mode: str) -> str:
    for candidate_theme in theme_chain(theme, mode):
        hit = find_in_theme(candidate_theme, name, mode)
        if hit:
            return hit
    hit = find_pixmap(name)
    if hit:
        return hit
    desk = desktop_icon_for_name(name)
    if desk:
        for candidate_theme in theme_chain(theme, mode):
            hit = find_in_theme(candidate_theme, desk, mode)
            if hit:
                return hit
        return find_pixmap(desk)
    return ""


def find_pixmap(name: str) -> str:
    for root in PIXMAP_ROOTS:
        for ext in EXTS:
            hit = root / f"{name}{ext}"
            if hit.is_file():
                return str(hit)
    return ""


def resolve(theme: str, name: str, mode: str) -> str:
    steam = resolve_steam_game(name, theme, mode)
    if steam:
        return steam
    return resolve_theme_only(theme, name, mode)


def main() -> int:
    if len(sys.argv) < 4:
        print("{}")
        return 0
    theme = sys.argv[1]
    mode = sys.argv[2] if sys.argv[2] in CATEGORIES else "mono"
    out = {name: resolve(theme, name, mode) for name in sys.argv[3:]}
    print(json.dumps(out))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
