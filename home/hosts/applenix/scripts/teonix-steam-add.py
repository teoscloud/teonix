#!/usr/bin/env python3
"""Add a non-Steam shortcut. Steam's Browse dialog is broken under Hyprland/muvm."""
from __future__ import annotations

import os
import struct
import subprocess
import sys
import zlib
from pathlib import Path


def die(msg: str) -> None:
    print(msg, file=sys.stderr)
    raise SystemExit(1)


def find_userdata() -> Path:
    roots = [
        Path.home() / ".local/share/Steam/userdata",
        Path.home() / ".steam/steam/userdata",
        Path.home() / ".steam/root/userdata",
    ]
    found: list[Path] = []
    for root in roots:
        if not root.is_dir():
            continue
        for p in root.iterdir():
            if p.name.isdigit() and p.name != "0" and p.is_dir():
                found.append(p)
    if not found:
        die("No Steam userdata yet — sign into Steam once, quit it fully, then retry.")
    # Prefer the most recently written config dir
    found.sort(key=lambda p: (p / "config").stat().st_mtime if (p / "config").exists() else 0, reverse=True)
    return found[0]


def steam_running() -> bool:
    try:
        out = subprocess.check_output(["pgrep", "-af", "steam"], text=True)
    except (OSError, subprocess.CalledProcessError):
        return False
    return any("steam" in line and "teonix-steam-add" not in line for line in out.splitlines())


def enc_str(key: str, val: str) -> bytes:
    return b"\x01" + key.encode() + b"\x00" + val.encode() + b"\x00"


def enc_i32(key: str, val: int) -> bytes:
    return b"\x02" + key.encode() + b"\x00" + struct.pack("<I", int(val) & 0xFFFFFFFF)


def enc_map(key: str, body: bytes) -> bytes:
    return b"\x00" + key.encode() + b"\x00" + body + b"\x08"


def appid_for(exe: str, name: str) -> int:
    return zlib.crc32((exe + name).encode()) | 0x80000000


def entry_body(index: int, exe: str, name: str, start_dir: str) -> bytes:
    quoted = f'"{exe}"'
    quoted_dir = f'"{start_dir}"'
    inner = b"".join(
        [
            enc_i32("appid", appid_for(exe, name)),
            enc_str("AppName", name),
            enc_str("Exe", quoted),
            enc_str("StartDir", quoted_dir),
            enc_str("icon", ""),
            enc_str("ShortcutPath", ""),
            enc_str("LaunchOptions", ""),
            enc_i32("IsHidden", 0),
            enc_i32("AllowDesktopConfig", 1),
            enc_i32("AllowOverlay", 1),
            enc_i32("OpenVR", 0),
            enc_i32("Devkit", 0),
            enc_str("DevkitGameID", ""),
            enc_i32("DevkitOverrideAppID", 0),
            enc_i32("LastPlayTime", 0),
            enc_str("FlatpakAppID", ""),
            enc_map("tags", b""),
        ]
    )
    return enc_map(str(index), inner)


def parse_count(data: bytes) -> int:
    """Count existing shortcut indices in a shortcuts.vdf blob."""
    if not data:
        return 0
    n = 0
    while True:
        needle = b"\x00" + str(n).encode() + b"\x00"
        if needle not in data:
            break
        n += 1
    return n


def main() -> None:
    if len(sys.argv) < 2:
        die("usage: teonix-steam-add /path/to/Game.exe [Name]")

    exe = Path(sys.argv[1]).expanduser().resolve()
    if not exe.is_file():
        die(f"not a file: {exe}")
    name = sys.argv[2] if len(sys.argv) > 2 else exe.stem
    start_dir = str(exe.parent) + os.sep

    if steam_running():
        die("Quit Steam fully first (it overwrites shortcuts.vdf on exit), then retry.")

    user = find_userdata()
    cfg = user / "config"
    cfg.mkdir(parents=True, exist_ok=True)
    path = cfg / "shortcuts.vdf"

    existing = path.read_bytes() if path.is_file() else b""
    if existing.startswith(b"\x00shortcuts\x00"):
        idx = parse_count(existing)
        # Strip trailing map-end bytes (two 0x08 after last entry / empty map)
        core = existing
        while core.endswith(b"\x08"):
            core = core[:-1]
        blob = core + entry_body(idx, str(exe), name, start_dir) + b"\x08\x08"
    elif not existing:
        blob = enc_map("shortcuts", entry_body(0, str(exe), name, start_dir)) + b"\x08"
    else:
        bak = path.with_suffix(".vdf.bak")
        bak.write_bytes(existing)
        print(f"unrecognized shortcuts.vdf — backed up to {bak}", file=sys.stderr)
        blob = enc_map("shortcuts", entry_body(0, str(exe), name, start_dir)) + b"\x08"

    tmp = path.with_suffix(".vdf.tmp")
    tmp.write_bytes(blob)
    tmp.replace(path)
    print(f"added {name!r} -> {exe}")
    print(f"wrote {path}")
    print("Start Steam, then: right-click the shortcut → Properties → Compatibility → Proton 10")


if __name__ == "__main__":
    main()
