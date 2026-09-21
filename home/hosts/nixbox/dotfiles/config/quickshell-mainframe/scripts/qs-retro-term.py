#!/usr/bin/env python3
"""Push the "Hacker cracker" look into cool-retro-term 1.2.0.

cool-retro-term keeps its settings in a Qt Quick LocalStorage SQLite database and
reads it only at startup (and re-saves its in-memory copy when a window closes).
For 1.2.0 that is

  $XDG_DATA_HOME/cool-retro-term/cool-retro-term/QML/OfflineStorage/Databases/
      <md5("coolretroterm1")>.sqlite            (Qt AppDataLocation is <org>/<app>)

with one table settings(setting, value) holding JSON strings under the keys
_CURRENT_SETTINGS (window/shell/fontNames), _CURRENT_PROFILE (the live look) and
_CUSTOM_PROFILES (the saved presets, each {text, obj_string, builtin}).

The whole terminal look is declared here — PROFILE is the "Hacker cracker" preset
captured from the app — so a fresh database or a wiped one comes back identical,
and the preset is re-added to the in-app profile list if it goes missing. The one
thing that still follows quickshell is the colour pair: PALETTES swaps
backgroundColor/fontColor for light and dark and leaves every effect untouched.

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

# "Hacker cracker", captured from the app's own saved profile. Effects, font and
# geometry are fixed; only the two colours below are swapped per theme.
PROFILE_NAME = "Hacker cracker"
PROFILE = {
    "flickering": 0.0552,
    "horizontalSync": 0.1508,
    "staticNoise": 0.0345,
    "chromaColor": 1,
    "saturationColor": 0.8517,
    "screenCurvature": 0,
    "glowingLine": 0.1476,
    "burnIn": 0.0503,
    "bloom": 0.3268,
    "rasterization": 0,
    "jitter": 0.0552,
    "rbgShift": 0,
    "brightness": 1,
    "contrast": 0.6232,
    "ambientLight": 0.1,
    "windowOpacity": 0.1501,
    "fontName": "System: IBM 3270",
    "fontWidth": 1.1,
    "margin": 0.1501,
    "blinkingCursor": True,
    "frameMargin": 0,
}

# Dark keeps the profile's own phosphor blue on black. Light is the neutral
# white plate with ink, so the tube flips with the quickshell theme.
PALETTES = {
    "dark": {"backgroundColor": "#000000", "fontColor": "#729fcf"},
    "light": {"backgroundColor": "#f4f5f7", "fontColor": "#1a1c1e"},
}

# fontNames is indexed by rasterization (0 none, 1 scanlines, 2 pixels). The
# profile uses the system IBM 3270 face, which only exists in the "none" list.
FONT_NAMES = ["System: IBM 3270", "IBM_PC", "IBM_PC"]


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
        profile = dict(PROFILE)
        profile.update(palette)

        settings["fontNames"] = FONT_NAMES
        settings["useCustomCommand"] = True
        settings["customCommand"] = SHELL

        # Keep the preset in the in-app profile list, so it can be re-picked by
        # hand. Stored as an obj_string, the way 1.2.0 writes it.
        presets = load(con, "_CUSTOM_PROFILES")
        if not isinstance(presets, list):
            presets = []
        entry = {"text": PROFILE_NAME, "obj_string": json.dumps(profile, indent=2),
                 "builtin": False}
        presets = [p for p in presets if p.get("text") != PROFILE_NAME] + [entry]

        store(con, "_CURRENT_SETTINGS", settings)
        store(con, "_CURRENT_PROFILE", profile)
        store(con, "_CUSTOM_PROFILES", presets)
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
