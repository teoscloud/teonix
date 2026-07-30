#!/usr/bin/env python3
"""Sample average color from the active hyprpaper wallpaper.

Prints one JSON object to stdout:
  {"r":0-1,"g":0-1,"b":0-1,"path":"...","hex":"#RRGGBB"}

Used by Quickshell overlays (Control Center / Spotlight / emoji) as a glass tint.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
CACHE = HOME / ".cache" / "qs-wallpaper-tint.json"


def wallpaper_path() -> Path | None:
    # Prefer live hyprpaper state
    try:
        out = subprocess.check_output(
            ["hyprctl", "hyprpaper", "listactive"],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2,
        )
        for line in out.splitlines():
            # "DP-1: /path/to/wall.jpg"
            if ":" in line:
                p = line.split(":", 1)[1].strip()
                if p and Path(p).is_file():
                    return Path(p)
    except Exception:
        pass

    conf = HOME / ".config" / "hypr" / "hyprpaper.conf"
    if conf.is_file():
        text = conf.read_text(encoding="utf-8", errors="replace")
        m = re.search(r"path\s*=\s*(\S+)", text)
        if m:
            p = Path(os.path.expanduser(m.group(1).strip().strip("\"'")))
            if p.is_file():
                return p
    return None


def sample_rgb(path: Path) -> tuple[int, int, int]:
    """Area-average via ffmpeg 1×1 downscale → RGB24 byte."""
    raw = subprocess.check_output(
        [
            "ffmpeg",
            "-v",
            "error",
            "-i",
            str(path),
            "-vf",
            "scale=1:1:flags=area",
            "-f",
            "rawvideo",
            "-pix_fmt",
            "rgb24",
            "-",
        ],
        timeout=8,
    )
    if len(raw) < 3:
        raise RuntimeError("ffmpeg returned empty sample")
    return raw[0], raw[1], raw[2]


def soften(r: float, g: float, b: float) -> tuple[float, float, float]:
    """Darken / slightly desaturate so glass stays readable over blur."""
    # Pull toward mid-dark while keeping hue
    target_lum = 0.28
    lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
    if lum > 1e-6:
        scale = target_lum / lum
        # Don't over-boost very dark walls
        scale = min(scale, 1.35)
        r, g, b = r * scale, g * scale, b * scale
    # Gentle desaturation toward the tint itself (keep character)
    grey = 0.2126 * r + 0.7152 * g + 0.0722 * b
    sat = 0.78
    r = grey * (1 - sat) + r * sat
    g = grey * (1 - sat) + g * sat
    b = grey * (1 - sat) + b * sat
    # Clamp
    return (
        max(0.0, min(1.0, r)),
        max(0.0, min(1.0, g)),
        max(0.0, min(1.0, b)),
    )


def main() -> int:
    path = wallpaper_path()
    if not path:
        print(json.dumps({"error": "no wallpaper", "r": 0.12, "g": 0.12, "b": 0.14}), flush=True)
        return 1

    try:
        R, G, B = sample_rgb(path)
        r, g, b = soften(R / 255.0, G / 255.0, B / 255.0)
    except Exception as e:
        print(json.dumps({"error": str(e), "r": 0.12, "g": 0.12, "b": 0.14, "path": str(path)}), flush=True)
        return 1

    payload = {
        "r": round(r, 4),
        "g": round(g, 4),
        "b": round(b, 4),
        "path": str(path),
        "hex": "#{:02x}{:02x}{:02x}".format(int(r * 255), int(g * 255), int(b * 255)),
    }
    try:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        CACHE.write_text(json.dumps(payload), encoding="utf-8")
    except Exception:
        pass
    print(json.dumps(payload), flush=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
