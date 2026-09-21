#!/usr/bin/env python3
"""Keep scrolling-layout column widths in pixels across a primary-monitor resize.

Hyprland's scrolling layout stores every column width as a FRACTION of the
workspace's usable width, so when the G9 flips between full (5120 wide) and PIP
(2560 wide) each column is squashed or stretched by 2x. This helper is run by
display-safe.sh `follow`:

  snapshot PRIMARY   Every few seconds: remember, per tiled window on PRIMARY's
                     workspaces, the pixel width it has (its "intended" width).
                     A column pinned at full width because its intended width
                     no longer fits keeps the intended value, so the round trip
                     full -> PIP -> full restores what the user had.
  rescale PRIMARY    After a resize: re-issue every column's width as
                     intended_px / new_usable_width (clamped by Hyprland to
                     [0.05, 1]). `layoutmsg colresize` only acts on the focused
                     window's column, so this visits each column with
                     focuswindow inside one hyprctl --batch, animations off,
                     then returns to the original workspace and window.

State lives in $XDG_RUNTIME_DIR/teonix-display/columns.json.
"""
import json
import os
import re
import subprocess
import sys

STATE_DIR = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "teonix-display")
STATE = os.path.join(STATE_DIR, "columns.json")
MIN_W, MAX_W = 0.05, 1.0


def hyprctl(*args):
    return subprocess.run(["hyprctl", *args], capture_output=True, text=True, check=False).stdout


def hj(*args):
    try:
        return json.loads(hyprctl("-j", *args))
    except ValueError:
        return None


def option_int(name):
    # "int: 1" or "custom type: 5 5 5 5" — first number is what we want.
    g = re.search(r"(-?\d+)", hyprctl("getoption", name) or "")
    return int(g.group(1)) if g else 0


def primary_info(name):
    for m in hj("monitors") or []:
        if m["name"] == name:
            res = m.get("reserved") or [0, 0, 0, 0]
            usable = int(m["width"] / (m.get("scale") or 1)) - res[0] - res[2]
            return m["id"], usable, m["activeWorkspace"]["id"]
    return None


def columns_on(mon_id):
    """First tiled window per column, keyed (workspace, x). Returns list of dicts."""
    cols = {}
    for w in hj("clients") or []:
        if w.get("monitor") != mon_id or w.get("floating") or w.get("hidden"):
            continue
        if not w.get("mapped", True) or w["workspace"]["id"] < 1 or w.get("fullscreen"):
            continue
        key = (w["workspace"]["id"], w["at"][0])
        cur = cols.get(key)
        if cur is None or w["at"][1] < cur["y"]:
            cols[key] = {"addr": w["address"], "ws": w["workspace"]["id"],
                         "x": w["at"][0], "y": w["at"][1], "px": w["size"][0]}
    return list(cols.values())


def load_state():
    try:
        with open(STATE) as fh:
            return json.load(fh)
    except (OSError, ValueError):
        return {"usable": 0, "windows": {}}


def save_state(st):
    os.makedirs(STATE_DIR, exist_ok=True)
    tmp = STATE + ".tmp"
    with open(tmp, "w") as fh:
        json.dump(st, fh)
    os.replace(tmp, STATE)


def gap():
    # column box -> window box: gaps_in on both sides plus the two borders.
    return 2 * option_int("general:gaps_in") + 2 * option_int("general:border_size")


def snapshot(primary):
    info = primary_info(primary)
    if not info:
        return 0
    mon_id, usable, _ = info
    g = gap()
    old = load_state().get("windows", {})
    windows = {}
    for c in columns_on(mon_id):
        live = c["px"]
        intended = old.get(c["addr"])
        # Pinned at full width while the intended width does not fit: keep it.
        # (A full column measures a little under usable - g because gaps_out
        # applies at the screen edges, hence the 3% slack.)
        if live + g >= usable * 0.97 and intended is not None and intended + g > usable:
            windows[c["addr"]] = intended
        else:
            windows[c["addr"]] = live
    save_state({"usable": usable, "windows": windows})
    return 0


def rescale(primary):
    info = primary_info(primary)
    if not info:
        return 0
    mon_id, usable, active_ws = info
    st = load_state()
    if st.get("usable") == usable:
        return 0  # width did not change; nothing to do
    g = gap()
    intended = st.get("windows", {})

    active = hj("activewindow") or {}
    active_addr = active.get("address")

    steps = []
    for c in columns_on(mon_id):
        want_px = intended.get(c["addr"])
        if want_px is None:
            continue
        want = max(MIN_W, min(MAX_W, (want_px + g) / usable))
        have = (c["px"] + g) / usable
        if abs(want - have) < 0.004:
            continue
        steps.append("dispatch focuswindow address:%s" % c["addr"])
        steps.append("dispatch layoutmsg colresize %.4f" % want)

    if steps:
        anim = option_int("animations:enabled")
        batch = ["keyword animations:enabled 0", *steps,
                 "dispatch workspace %d" % active_ws]
        if active_addr and active_addr != "0x0":
            batch.append("dispatch focuswindow address:%s" % active_addr)
        batch.append("keyword animations:enabled %d" % anim)
        hyprctl("--batch", " ; ".join(batch))
        print("scroll-columns: resized %d column(s) for usable width %d"
              % (len(steps) // 2, usable), file=sys.stderr)

    # Re-snapshot against the new width, keeping intended widths for columns
    # that are now pinned at full width.
    snapshot(primary)
    return 0


if __name__ == "__main__":
    if len(sys.argv) != 3 or sys.argv[1] not in ("snapshot", "rescale"):
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    sys.exit(globals()[sys.argv[1]](sys.argv[2]))
