#!/usr/bin/env python3
"""Push the qs-mainframe palette into cool-retro-term 1.2.0.

cool-retro-term keeps its settings in a Qt Quick LocalStorage SQLite database and
reads it only at startup (and re-saves its in-memory copy when a window closes).
For 1.2.0 that is

  $XDG_DATA_HOME/cool-retro-term/cool-retro-term/QML/OfflineStorage/Databases/
      <md5("coolretroterm1")>.sqlite            (Qt AppDataLocation is <org>/<app>)

with one table settings(setting, value) holding JSON strings under the keys
_CURRENT_SETTINGS (window/shell/fontNames) and _CURRENT_PROFILE (look).

This owns exactly three things and merges them into whatever is stored, so the
user's own ricing (effects, curvature, window size, rasterization) is kept:
  - colours:  backgroundColor / fontColor from the palette
  - font:     an IBM face in every rasterization slot (fontNames + fontName)
  - shell:    useCustomCommand + customCommand = zsh

Usage: qs-retro-term.py light|dark
"""
import hashlib
import json
import os
import sys
import sqlite3

DB_NAME = "coolretroterm1"   # Storage.qml in 1.2.0
DB_VERSION = "1.0"
DB_HASH = hashlib.md5(DB_NAME.encode()).hexdigest()  # 27e743fe85b8912a46804fed99e8a9ab

SHELL = "/run/current-system/sw/bin/zsh"

# Colour-neutral, straight from the qs tokens: no phosphor tint. Dark is the
# charcoal bar (tokens-dark bg / fg); light is the white plate (tokens-light
# trayPlate / fg) — a bright tube, not a black screen. cool-retro-term blends
# the background ~7% towards fontColor at the user's contrast, which with a
# grey fontColor only shifts the grey, so both stay neutral.
PALETTES = {
    "dark": {"backgroundColor": "#101214", "fontColor": "#e8eaee"},
    "light": {"backgroundColor": "#f4f5f7", "fontColor": "#1a1c1e"},
}

# fontNames is indexed by rasterization (0 none, 1 scanlines, 2 pixels) and each
# mode has its own font list in 1.2.0. IBM faces available per list:
#   none:      IBM_DOS, IBM_3278, IBM_PC_SCALED
#   scanlines: IBM_PC
#   pixels:    IBM_PC
# A slot already holding an IBM_* face (the user's own pick) is left alone.
IBM_DEFAULT = ["IBM_3278", "IBM_PC", "IBM_PC"]


def db_dir():
    base = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    return os.path.join(base, "cool-retro-term", "cool-retro-term",
                        "QML", "OfflineStorage", "Databases")


def load(con, key):
    row = con.execute("SELECT value FROM settings WHERE setting = ?", (key,)).fetchone()
    if not row:
        return {}
    try:
        return json.loads(row[0])
    except ValueError:
        return {}


def store(con, key, obj):
    con.execute("INSERT OR REPLACE INTO settings VALUES (?, ?)", (key, json.dumps(obj)))


def write(mode):
    palette = PALETTES.get(mode, PALETTES["dark"])

    path = db_dir()
    os.makedirs(path, exist_ok=True)
    sqlite = os.path.join(path, DB_HASH + ".sqlite")
    fresh = not os.path.exists(sqlite)

    con = sqlite3.connect(sqlite)
    try:
        con.execute("CREATE TABLE IF NOT EXISTS settings(setting TEXT UNIQUE, value TEXT)")

        settings = load(con, "_CURRENT_SETTINGS")
        profile = load(con, "_CURRENT_PROFILE")

        names = list(settings.get("fontNames") or [])
        while len(names) < 3:
            names.append(IBM_DEFAULT[len(names)])
        names = [n if str(n).startswith("IBM_") else IBM_DEFAULT[i]
                 for i, n in enumerate(names[:3])]
        settings["fontNames"] = names
        settings["useCustomCommand"] = True
        settings["customCommand"] = SHELL

        raster = profile.get("rasterization", 0)
        if not isinstance(raster, int) or not 0 <= raster < 3:
            raster = 0
        profile["fontName"] = names[raster]
        profile.update(palette)

        store(con, "_CURRENT_SETTINGS", settings)
        store(con, "_CURRENT_PROFILE", profile)
        con.commit()
    finally:
        con.close()

    # Qt refuses to open a .sqlite without its .ini sidecar.
    ini = os.path.join(path, DB_HASH + ".ini")
    if fresh or not os.path.exists(ini):
        with open(ini, "w") as fh:
            fh.write(
                "[General]\n"
                "Description=StorageDatabase\n"
                "Driver=QSQLITE\n"
                "EstimatedSize=100000\n"
                "Name=%s\n"
                "Version=%s\n" % (DB_NAME, DB_VERSION)
            )


if __name__ == "__main__":
    write(sys.argv[1] if len(sys.argv) > 1 else "dark")
