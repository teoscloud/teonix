#!/usr/bin/env python3
# Generate a mutter monitors.xml for whatever is plugged in right now.
#
# Nothing here names a monitor, a connector or a card index: outputs come from
# sysfs, identity and timings come from the EDID, and the mode is chosen under
# the same pixel-rate budget display-safe.sh uses.
#
# The greeter gets exactly ONE output — the largest panel, at its biggest allowed
# mode — and every other connected monitor is listed as disabled. Mutter cannot
# drive this card's three-output layout: with the ultrawide plus two 1080p panels
# it accepted the modeset and then failed every page flip
# ("drmModeAtomicCommit: Invalid argument"), leaving all screens black at the
# login prompt on 2026-09-10. Hyprland runs the same three outputs happily, so
# this is a mutter/DCE 11.2 limit, not a bandwidth ceiling — and a stored config
# is treated as policy, so mutter forces it instead of falling back the way it
# does with a layout of its own choosing. One output is the whole fix: fewest
# CRTCs, fewest planes, and the prompt lands dead centre on the big panel.
# Everything else lights up a second later when the session starts.

import glob
import os
import re
import subprocess
import sys

BW_CONF = "/etc/teonix/display-bandwidth.conf"


def pixel_budget():
    try:
        with open(BW_CONF) as fh:
            for line in fh:
                if line.startswith("TEONIX_MAX_PIXEL_RATE_MPS="):
                    return float(line.split("=", 1)[1].strip())
    except OSError:
        pass
    return None


def decode(edid_bytes):
    try:
        proc = subprocess.run(
            ["edid-decode"], input=edid_bytes,
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
        )
    except OSError:
        return None
    text = proc.stdout.decode("utf-8", "replace")

    vendor = re.search(r"^\s*Manufacturer:\s*(\S+)", text, re.M)
    product = re.search(r"^\s*Display Product Name:\s*'([^']*)'", text, re.M)
    serial = re.search(r"^\s*Display Product Serial Number:\s*'([^']*)'", text, re.M)
    if not (vendor and product and serial):
        return None

    # Every mode edid-decode reports, from any block: "WxH  R Hz". The trailing
    # \s is what excludes interlaced entries, which print as "1920x1080i".
    modes = set()
    for m in re.finditer(r"\b(\d{3,5})x(\d{3,4})\s+([\d.]+)\s*Hz", text):
        modes.add((int(m.group(1)), int(m.group(2)), float(m.group(3))))
    if not modes:
        return None

    return {
        "vendor": vendor.group(1),
        "product": product.group(1),
        "serial": serial.group(1),
        "modes": sorted(modes),
    }


def best_mode(modes, budget):
    allowed = [
        (w, h, r) for (w, h, r) in modes
        if budget is None or w * h * r / 1e6 <= budget + 1
    ]
    if not allowed:
        return None
    # Biggest picture, then the refresh nearest 60 Hz at that size. A greeter has
    # no use for high refresh, and "nearest 60" lands on the panel's own native
    # timing rather than a broadcast 50 Hz entry or a GTF/CVT-derived rate the
    # kernel may not actually offer — a mode mutter cannot find makes the whole
    # configuration inapplicable. Ties go to the faster mode.
    area = max(w * h for (w, h, _) in allowed)
    return min(
        (m for m in allowed if m[0] * m[1] == area),
        key=lambda m: (abs(m[2] - 60.0), -m[2]),
    )


def collect():
    found = []
    for status_path in sorted(glob.glob("/sys/class/drm/card*-*/status")):
        base = os.path.dirname(status_path)
        try:
            with open(status_path) as fh:
                if fh.read().strip() != "connected":
                    continue
            with open(os.path.join(base, "edid"), "rb") as fh:
                edid = fh.read()
        except OSError:
            continue
        if not edid:
            continue
        info = decode(edid)
        if info is None:
            print("skip %s: unusable EDID" % base, file=sys.stderr)
            continue
        # card1-DP-1 -> DP-1
        info["connector"] = os.path.basename(base).split("-", 1)[1]
        found.append(info)
    return found


def plan(monitors, budget):
    """[(monitor, mode)], largest panel first. None if any output has no mode."""
    chosen = []
    for mon in monitors:
        mode = best_mode(mon["modes"], budget)
        if mode is None:
            return None
        chosen.append((mon, mode))
    chosen.sort(key=lambda c: (c[1][0] * c[1][1], c[0]["connector"]), reverse=True)
    return chosen


def spec(mon, indent):
    pad = " " * indent
    return [
        pad + "<monitorspec>",
        pad + "  <connector>%s</connector>" % mon["connector"],
        pad + "  <vendor>%s</vendor>" % mon["vendor"],
        pad + "  <product>%s</product>" % mon["product"],
        pad + "  <serial>%s</serial>" % mon["serial"],
        pad + "</monitorspec>",
    ]


def build(chosen):
    mon, (w, h, r) = chosen[0]

    out = ['<monitors version="2">', "  <configuration>",
           "    <layoutmode>logical</layoutmode>",
           "    <logicalmonitor>",
           "      <x>0</x>",
           "      <y>0</y>",
           "      <scale>1</scale>",
           "      <primary>yes</primary>",
           "      <monitor>"]
    out += spec(mon, 8)
    out += [
        "        <mode>",
        "          <width>%d</width>" % w,
        "          <height>%d</height>" % h,
        "          <rate>%.3f</rate>" % r,
        "        </mode>",
        "      </monitor>",
        "    </logicalmonitor>",
    ]

    # A stored configuration only applies if it accounts for every connected
    # monitor, so the ones the greeter leaves dark have to be named here.
    if len(chosen) > 1:
        out.append("    <disabled>")
        for rest, _ in chosen[1:]:
            out += spec(rest, 6)
        out.append("    </disabled>")

    out += ["  </configuration>", "</monitors>", ""]
    return "\n".join(out)


def main():
    budget = pixel_budget()
    monitors = collect()
    if not monitors:
        print("no connected outputs with a usable EDID; leaving greeter alone",
              file=sys.stderr)
        return 0
    chosen = plan(monitors, budget)
    if chosen is None:
        print("no mode within the pixel budget; leaving greeter alone",
              file=sys.stderr)
        return 0
    xml = build(chosen)

    target = sys.argv[1] if len(sys.argv) > 1 else "-"
    if target == "-":
        sys.stdout.write(xml)
        return 0

    os.makedirs(os.path.dirname(target), mode=0o755, exist_ok=True)
    tmp = target + ".new"
    with open(tmp, "w") as fh:
        fh.write(xml)
    os.chmod(tmp, 0o644)
    os.replace(tmp, target)
    for index, (mon, mode) in enumerate(chosen):
        if index == 0:
            print("greeter: %s %dx%d@%.3f" % (
                mon["connector"], mode[0], mode[1], mode[2]))
        else:
            print("greeter: %s off until the session starts" % mon["connector"])
    return 0


if __name__ == "__main__":
    sys.exit(main())
