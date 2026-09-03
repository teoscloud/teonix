#!/usr/bin/env python3
"""One-shot CPU / RAM / net rates for the mainframe top strip.

Compares against a snapshot in $XDG_RUNTIME_DIR so each invoke is instant.
Prints: {"cpu":12,"ram":44,"rx":"1.2M","tx":"80K"}
"""
from __future__ import annotations

import json
import os
import time

STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "qs-mainframe-sys.json")

SKIP_IFACE_PREFIX = (
    "lo",
    "docker",
    "veth",
    "br-",
    "virbr",
    "vnet",
    "tap",
    "ifb",
    "dummy",
)


def cpu_times() -> tuple[int, int]:
    with open("/proc/stat", encoding="utf-8") as f:
        nums = [int(x) for x in f.readline().split()[1:]]
    idle = nums[3] + (nums[4] if len(nums) > 4 else 0)
    return idle, sum(nums)


def ram_pct() -> int:
    tot = avail = 0
    with open("/proc/meminfo", encoding="utf-8") as f:
        for line in f:
            if line.startswith("MemTotal:"):
                tot = int(line.split()[1])
            elif line.startswith("MemAvailable:"):
                avail = int(line.split()[1])
            if tot and avail:
                break
    if tot <= 0:
        return 0
    return int(round(max(0, min(100, (tot - avail) * 100 / tot))))


def skip_iface(name: str) -> bool:
    return any(name == p or name.startswith(p) for p in SKIP_IFACE_PREFIX)


def net_bytes() -> tuple[int, int]:
    rx = tx = 0
    with open("/proc/net/dev", encoding="utf-8") as f:
        for line in f:
            if ":" not in line:
                continue
            name, rest = line.split(":", 1)
            name = name.strip()
            if skip_iface(name):
                continue
            cols = rest.split()
            rx += int(cols[0])
            tx += int(cols[8])
    return rx, tx


def fmt_rate(bps: float) -> str:
    if bps < 0:
        bps = 0
    if bps < 1024:
        return f"{int(bps)}B"
    if bps < 1024 * 1024:
        v = bps / 1024
        return f"{v:.0f}K" if v >= 10 else f"{v:.1f}K"
    v = bps / (1024 * 1024)
    return f"{v:.1f}M" if v < 100 else f"{v:.0f}M"


def main() -> None:
    now = time.monotonic()
    idle, total = cpu_times()
    rx, tx = net_bytes()
    cpu = 0
    rx_bps = tx_bps = 0.0
    try:
        with open(STATE, encoding="utf-8") as f:
            prev = json.load(f)
        dt = max(0.2, now - float(prev.get("t", now)))
        dtot = total - int(prev["total"])
        if dtot > 0:
            di = idle - int(prev["idle"])
            cpu = int(round(max(0, min(100, (1.0 - di / dtot) * 100))))
        rx_bps = (rx - int(prev["rx"])) / dt
        tx_bps = (tx - int(prev["tx"])) / dt
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        pass

    tmp = STATE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"t": now, "idle": idle, "total": total, "rx": rx, "tx": tx}, f)
    os.replace(tmp, STATE)

    print(
        json.dumps({"cpu": cpu, "ram": ram_pct(), "rx": fmt_rate(rx_bps), "tx": fmt_rate(tx_bps)}),
        flush=True,
    )


if __name__ == "__main__":
    main()
