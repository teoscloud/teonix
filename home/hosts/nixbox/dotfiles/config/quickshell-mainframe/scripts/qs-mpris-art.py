#!/usr/bin/env python3
"""Resolve real MPRIS cover art when Chromium/Brave publishes its app icon.

Brave/Chrome often set mpris:artUrl to a /tmp/.org.chromium.* dump of the
browser mark. For YouTube titles we map to i.ytimg.com (from xesam:url or
yt-dlp search). Prints one URL or nothing.
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path
from urllib.parse import unquote, urlparse

CACHE = Path.home() / ".cache" / "qs-mpris-art.json"
CHROMIUM_TMP = re.compile(r"/tmp/\.org\.chromium\.", re.I)
YID = re.compile(
    r"(?:youtube\.com/(?:watch\?v=|embed/|shorts/|live/)|youtu\.be/)"
    r"([A-Za-z0-9_-]{11})"
)
YT_SUFFIXES = (" - YouTube", " | YouTube", " • YouTube")


def env(name: str) -> str:
    return (os.environ.get(name) or "").strip()


def youtube_id(text: str) -> str:
    m = YID.search(text or "")
    return m.group(1) if m else ""


def thumb_url(vid: str) -> str:
    return f"https://i.ytimg.com/vi/{vid}/hqdefault.jpg"


def file_from_art(url: str) -> Path | None:
    if not url:
        return None
    raw = url
    if raw.startswith("file://"):
        raw = unquote(urlparse(raw).path)
    p = Path(raw)
    return p if p.is_file() else None


def is_chromium_tmp(url: str) -> bool:
    return bool(CHROMIUM_TMP.search(url or ""))


def chromium_tmp_usable(url: str) -> bool:
    """Keep large Chromium dumps (real frames); drop ~30KB app-icon stubs."""
    if not is_chromium_tmp(url):
        return False
    p = file_from_art(url)
    if p is None:
        return False
    try:
        return p.stat().st_size >= 80_000
    except OSError:
        return False


def art_usable(url: str) -> bool:
    if not url:
        return False
    low = url.lower()
    if is_chromium_tmp(url):
        return chromium_tmp_usable(url)
    if low.startswith("http://") or low.startswith("https://"):
        if "favicon" in low or "google.com/s2/favicons" in low:
            return False
        return True
    if low.startswith("file://") or url.startswith("/"):
        return file_from_art(url) is not None
    return False


def search_query(title: str) -> str:
    t = (title or "").strip()
    for suf in YT_SUFFIXES:
        if t.endswith(suf):
            t = t[: -len(suf)].strip()
    return t


def looks_youtube(title: str, track_url: str) -> bool:
    blob = f"{title} {track_url}".lower()
    if "youtube" in blob or "youtu.be" in blob:
        return True
    return any(title.endswith(s) for s in YT_SUFFIXES)


def load_cache() -> dict:
    try:
        return json.loads(CACHE.read_text(encoding="utf-8"))
    except Exception:
        return {}


def save_cache(data: dict) -> None:
    try:
        CACHE.parent.mkdir(parents=True, exist_ok=True)
        CACHE.write_text(json.dumps(data, indent=0), encoding="utf-8")
    except OSError:
        pass


def cached_id(title: str) -> str:
    rec = load_cache().get(title)
    if isinstance(rec, dict):
        return str(rec.get("id") or "")
    if isinstance(rec, str) and len(rec) == 11:
        return rec
    return ""


def store_id(title: str, vid: str) -> None:
    if not title or not vid:
        return
    data = load_cache()
    data[title] = {"id": vid, "url": thumb_url(vid)}
    save_cache(data)


def playerctl_name(dbus_name: str) -> str:
    prefix = "org.mpris.MediaPlayer2."
    if dbus_name.startswith(prefix):
        return dbus_name[len(prefix) :]
    return dbus_name


def dbus_fill(dbus_name: str) -> tuple[str, str, str, str]:
    """title, art, url, identity from the live player."""
    title = art = url = identity = ""
    if not dbus_name:
        return title, art, url, identity
    inst = playerctl_name(dbus_name)
    try:
        out = subprocess.check_output(
            [
                "playerctl",
                "-p",
                inst,
                "metadata",
                "--format",
                "{{xesam:title}}\n{{mpris:artUrl}}\n{{xesam:url}}\n{{playerName}}",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=2,
        )
        lines = out.splitlines()
        title = lines[0] if len(lines) > 0 else ""
        art = lines[1] if len(lines) > 1 else ""
        url = lines[2] if len(lines) > 2 else ""
        identity = lines[3] if len(lines) > 3 else ""
    except Exception:
        pass
    return title, art, url, identity


def yt_search_id(title: str) -> str:
    q = search_query(title)
    if not q:
        return ""
    try:
        out = subprocess.check_output(
            [
                "yt-dlp",
                "--no-warnings",
                "--no-playlist",
                "--print",
                "%(id)s",
                f"ytsearch1:{q}",
            ],
            text=True,
            stderr=subprocess.DEVNULL,
            timeout=18,
        )
        vid = (out.strip().splitlines() or [""])[0].strip()
        if re.fullmatch(r"[A-Za-z0-9_-]{11}", vid):
            return vid
    except Exception:
        pass
    return ""


def main() -> int:
    title = env("QS_MPRIS_TITLE")
    art = env("QS_MPRIS_ART")
    url = env("QS_MPRIS_URL")
    identity = env("QS_MPRIS_IDENTITY")
    dbus_name = env("QS_MPRIS_DBUS") or (sys.argv[1] if len(sys.argv) > 1 else "")

    dt, da, du, di = dbus_fill(dbus_name)
    title = title or dt
    art = art or da
    url = url or du
    identity = identity or di

    vid = youtube_id(url) or youtube_id(title) or youtube_id(art)
    if not vid:
        vid = cached_id(title)

    if vid:
        print(thumb_url(vid), flush=True)
        return 0

    if looks_youtube(title, url):
        vid = yt_search_id(title)
        if vid:
            store_id(title, vid)
            print(thumb_url(vid), flush=True)
            return 0

    if art_usable(art):
        print(art, flush=True)
        return 0

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
