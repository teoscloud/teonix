#!/usr/bin/env python3
"""One-shot CPU / RAM / battery for the mainframe top strip.

Compares against a snapshot in $XDG_RUNTIME_DIR so each invoke is instant.
Prints: {"cpu":12,"ram":44,"bat_present":true,"bat":72,"bat_status":"Discharging","bat_ac":false}
"""
from __future__ import annotations

import json
import os
import time

STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "qs-mainframe-sys.json")


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


def _read_int(path: str) -> int | None:
    try:
        with open(path, encoding="utf-8") as f:
            return int(f.read().strip())
    except (OSError, ValueError):
        return None


def _read_str(path: str) -> str:
    try:
        with open(path, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


def mains_online() -> bool:
    base = "/sys/class/power_supply"
    try:
        names = os.listdir(base)
    except OSError:
        return False
    for name in sorted(names):
        path = os.path.join(base, name)
        if _read_str(os.path.join(path, "type")) != "Mains":
            continue
        if _read_str(os.path.join(path, "online")) == "1":
            return True
    return False


def battery() -> dict:
    """System battery from sysfs (Asahi macsmc-battery, BAT0, …)."""
    base = "/sys/class/power_supply"
    try:
        names = os.listdir(base)
    except OSError:
        return {"bat_present": False, "bat_ac": mains_online()}

    chosen = ""
    for name in sorted(names):
        path = os.path.join(base, name)
        if _read_str(os.path.join(path, "type")) != "Battery":
            continue
        if _read_str(os.path.join(path, "present")) == "0":
            continue
        if _read_str(os.path.join(path, "scope")) == "Device":
            continue
        chosen = path
        if _read_str(os.path.join(path, "scope")) == "System":
            break
    if not chosen:
        return {"bat_present": False, "bat_ac": mains_online()}

    cap = _read_int(os.path.join(chosen, "capacity"))
    if cap is None:
        now = _read_int(os.path.join(chosen, "energy_now"))
        full = _read_int(os.path.join(chosen, "energy_full"))
        if now is None or not full:
            now = _read_int(os.path.join(chosen, "charge_now"))
            full = _read_int(os.path.join(chosen, "charge_full"))
        if now is not None and full:
            cap = int(round(max(0, min(100, now * 100.0 / full))))
        else:
            cap = 0
    else:
        cap = max(0, min(100, cap))

    status = _read_str(os.path.join(chosen, "status")) or "Unknown"
    return {
        "bat_present": True,
        "bat": cap,
        "bat_status": status,
        "bat_ac": mains_online(),
    }


def main() -> None:
    now = time.monotonic()
    idle, total = cpu_times()
    cpu = 0
    try:
        with open(STATE, encoding="utf-8") as f:
            prev = json.load(f)
        dtot = total - int(prev["total"])
        if dtot > 0:
            di = idle - int(prev["idle"])
            cpu = int(round(max(0, min(100, (1.0 - di / dtot) * 100))))
    except (OSError, KeyError, TypeError, ValueError, json.JSONDecodeError):
        pass

    tmp = STATE + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"t": now, "idle": idle, "total": total}, f)
    os.replace(tmp, STATE)

    out = {"cpu": cpu, "ram": ram_pct()}
    out.update(battery())
    print(json.dumps(out), flush=True)


if __name__ == "__main__":
    main()
