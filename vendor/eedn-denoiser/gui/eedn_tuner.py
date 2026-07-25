#!/usr/bin/env python3
"""EEDN quick tuner — edit band Hz + range, write conf, restart service."""

from __future__ import annotations

import re
import subprocess
import sys
import tkinter as tk
from pathlib import Path
from tkinter import messagebox, ttk

CONF = Path.home() / ".config/pipewire/filter-chain.conf.d/eedn-pcm2902-mic.conf"
SERVICE = "eedn-pcm2902.service"

MAC = {
    "Threshold (dB)": -88.2,
    "Range Band 1 (dB)": 0.8,
    "Range Band 2 (dB)": 0.8,
    "Range Band 3 (dB)": 6.1,
    "Range Band 4 (dB)": 11.4,
    "Range Band 5 (dB)": 5.5,
    "Range Band 6 (dB)": 5.5,
    "Band 1 Freq (Hz)": 250.0,
    "Band 2 Freq (Hz)": 574.0,
    "Band 3 Freq (Hz)": 1300.0,
    "Band 4 Freq (Hz)": 3000.0,
    "Band 5 Freq (Hz)": 7000.0,
    "Band 6 Freq (Hz)": 16000.0,
    "HF Bias": 0.35,
    "Stereo Link": 0.85,
    "Bypass": 0.0,
}

GENTLE = {
    # Generic fallback — NOT measured from your hardware.
    "Threshold (dB)": -48.0,
    "Range Band 1 (dB)": 8.0,
    "Range Band 2 (dB)": 9.0,
    "Range Band 3 (dB)": 7.0,
    "Range Band 4 (dB)": 8.0,
    "Range Band 5 (dB)": 12.0,
    "Range Band 6 (dB)": 14.0,
    "Band 1 Freq (Hz)": 60.0,
    "Band 2 Freq (Hz)": 180.0,
    "Band 3 Freq (Hz)": 500.0,
    "Band 4 Freq (Hz)": 1500.0,
    "Band 5 Freq (Hz)": 4500.0,
    "Band 6 Freq (Hz)": 12000.0,
    "HF Bias": 0.35,
    "Stereo Link": 0.85,
    "Bypass": 0.0,
}

# Default / seed preset — captured from live tuner session (UserTuned).
USER_TUNED = {
    "Threshold (dB)": -44.1146,
    "Range Band 1 (dB)": 12.0,
    "Range Band 2 (dB)": 11.5,
    "Range Band 3 (dB)": 8.0,
    "Range Band 4 (dB)": 14.0,
    "Range Band 5 (dB)": 12.5115,
    "Range Band 6 (dB)": 15.0295,
    "Band 1 Freq (Hz)": 120.0,
    "Band 2 Freq (Hz)": 240.0,
    "Band 3 Freq (Hz)": 600.0,
    "Band 4 Freq (Hz)": 1580.0,
    "Band 5 Freq (Hz)": 3000.0,
    "Band 6 Freq (Hz)": 12000.0,
    "HF Bias": 0.40,
    "Stereo Link": 0.90,
    "Bypass": 0.0,
}

# Earlier silent-capture layout (pre UserTuned threshold/range tweaks).
PCM2902_MEASURED = {
    "Threshold (dB)": -69.0,
    "Range Band 1 (dB)": 12.0,
    "Range Band 2 (dB)": 11.5,
    "Range Band 3 (dB)": 8.0,
    "Range Band 4 (dB)": 14.0,
    "Range Band 5 (dB)": 12.5,
    "Range Band 6 (dB)": 10.0,
    "Band 1 Freq (Hz)": 120.0,
    "Band 2 Freq (Hz)": 240.0,
    "Band 3 Freq (Hz)": 600.0,
    "Band 4 Freq (Hz)": 1580.0,
    "Band 5 Freq (Hz)": 3000.0,
    "Band 6 Freq (Hz)": 12000.0,
    "HF Bias": 0.40,
    "Stereo Link": 0.90,
    "Bypass": 0.0,
}

PRESETS = {
    "UserTuned": USER_TUNED,
    "PCM2902 Measured": PCM2902_MEASURED,
    "Mac Bertom": MAC,
    "Gentle (generic)": GENTLE,
}

BANDS = [
    ("Band 1 Freq (Hz)", "Range Band 1 (dB)"),
    ("Band 2 Freq (Hz)", "Range Band 2 (dB)"),
    ("Band 3 Freq (Hz)", "Range Band 3 (dB)"),
    ("Band 4 Freq (Hz)", "Range Band 4 (dB)"),
    ("Band 5 Freq (Hz)", "Range Band 5 (dB)"),
    ("Band 6 Freq (Hz)", "Range Band 6 (dB)"),
]


def parse_conf(text: str) -> dict[str, float]:
    return {m.group(1): float(m.group(2)) for m in re.finditer(r'"([^"]+)"\s*=\s*([-+0-9.]+)', text)}


def write_conf(path: Path, values: dict[str, float]) -> None:
    text = path.read_text()
    # Drop obsolete keys if present (Freq Low/High from older tuner)
    for obsolete in ("Freq Low (Hz)", "Freq High (Hz)"):
        text = re.sub(rf'\s*"{re.escape(obsolete)}"\s*=\s*[-+0-9.]+\s*\n', "\n", text)

    for key, val in values.items():
        pattern = rf'("{re.escape(key)}"\s*=\s*)([-+0-9.]+)'
        text2, n = re.subn(pattern, rf"\g<1>{val:g}", text, count=1)
        if n == 0:
            # Insert before HF Bias line inside control block
            insert = f'                          "{key}"   = {val:g}\n'
            if '"HF Bias"' in text2:
                text2 = text2.replace('                          "HF Bias"', insert + '                          "HF Bias"', 1)
            else:
                raise KeyError(f"control not found in conf: {key}")
        text = text2
    path.write_text(text)


def restart_service() -> tuple[bool, str]:
    try:
        r = subprocess.run(
            ["systemctl", "--user", "restart", SERVICE],
            capture_output=True,
            text=True,
            check=False,
        )
        if r.returncode != 0:
            return False, (r.stderr or r.stdout or f"exit {r.returncode}").strip()
        return True, "restarted"
    except FileNotFoundError:
        return False, "systemctl not found"


def fmt_hz(hz: float) -> str:
    return f"{hz / 1000:.2f} kHz" if hz >= 1000 else f"{hz:.0f} Hz"


class Tuner(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title("EEDN Denoiser Tuner")
        self.geometry("640x560")
        self.vars: dict[str, tk.DoubleVar] = {}

        if not CONF.exists():
            messagebox.showerror("Missing config", f"No conf at\n{CONF}")
            self.destroy()
            return

        current = parse_conf(CONF.read_text())
        base = dict(USER_TUNED)
        base.update({k: current[k] for k in base if k in current})

        top = ttk.Frame(self, padding=10)
        top.pack(fill="x")
        ttk.Label(top, text="Preset").pack(side="left")
        self.preset = tk.StringVar(value="UserTuned")
        cb = ttk.Combobox(top, textvariable=self.preset, values=list(PRESETS), state="readonly", width=22)
        cb.pack(side="left", padx=8)
        cb.bind("<<ComboboxSelected>>", lambda _e: self.load_preset(self.preset.get()))
        ttk.Button(top, text="Apply + Restart", command=self.apply).pack(side="right")
        ttk.Button(top, text="Reload file", command=self.reload_file).pack(side="right", padx=6)

        ttk.Label(
            self,
            text="Edit each band’s center Hz and max reduction (Range). Apply restarts the service.",
            padding=(10, 0),
        ).pack(fill="x")

        body = ttk.Frame(self, padding=10)
        body.pack(fill="both", expand=True)

        # Threshold
        self._slider_row(body, "Threshold (dB)", -140.0, 0.0, base["Threshold (dB)"])

        hdr = ttk.Frame(body)
        hdr.pack(fill="x", pady=(12, 2))
        ttk.Label(hdr, text="Band", width=8).pack(side="left")
        ttk.Label(hdr, text="Freq (Hz)", width=12).pack(side="left")
        ttk.Label(hdr, text="Range / max reduction (dB)").pack(side="left", padx=8)

        for i, (hz_key, range_key) in enumerate(BANDS):
            row = ttk.Frame(body)
            row.pack(fill="x", pady=4)
            ttk.Label(row, text=f"#{i + 1}", width=8).pack(side="left")

            hz_var = tk.DoubleVar(value=float(base[hz_key]))
            self.vars[hz_key] = hz_var
            hz_ent = ttk.Entry(row, width=10, justify="right")
            hz_ent.pack(side="left")
            hz_ent.insert(0, f"{hz_var.get():g}")
            hz_ent.bind("<Return>", lambda _e, k=hz_key, e=hz_ent: self.from_entry(k, e))
            hz_ent.bind("<FocusOut>", lambda _e, k=hz_key, e=hz_ent: self.from_entry(k, e))
            hz_var.trace_add("write", lambda *_a, e=hz_ent, v=hz_var: self.sync_entry(e, v, hz=True))

            hint = ttk.Label(row, width=10)
            hint.pack(side="left", padx=4)
            hz_var.trace_add("write", lambda *_a, h=hint, v=hz_var: h.configure(text=fmt_hz(v.get())))
            hint.configure(text=fmt_hz(hz_var.get()))

            range_var = tk.DoubleVar(value=float(base[range_key]))
            self.vars[range_key] = range_var
            scale = ttk.Scale(row, from_=0.0, to=24.0, variable=range_var)
            scale.pack(side="left", fill="x", expand=True, padx=6)
            ren = ttk.Entry(row, width=7, justify="right")
            ren.pack(side="right")
            ren.insert(0, f"{range_var.get():.2f}")
            range_var.trace_add("write", lambda *_a, e=ren, v=range_var: self.sync_entry(e, v))
            ren.bind("<Return>", lambda _e, k=range_key, e=ren: self.from_entry(k, e))
            ren.bind("<FocusOut>", lambda _e, k=range_key, e=ren: self.from_entry(k, e))

        self._slider_row(body, "HF Bias", 0.0, 1.0, base["HF Bias"])
        self._slider_row(body, "Stereo Link", 0.0, 1.0, base["Stereo Link"])

        bypass = tk.DoubleVar(value=float(base.get("Bypass", 0.0)))
        self.vars["Bypass"] = bypass
        tk.Checkbutton(body, text="Bypass", variable=bypass, onvalue=1.0, offvalue=0.0).pack(anchor="w", pady=8)

        self.status = ttk.Label(self, text=str(CONF), padding=10)
        self.status.pack(fill="x")

    def _slider_row(self, parent: ttk.Frame, name: str, lo: float, hi: float, value: float) -> None:
        row = ttk.Frame(parent)
        row.pack(fill="x", pady=3)
        ttk.Label(row, text=name, width=18).pack(side="left")
        var = tk.DoubleVar(value=float(value))
        self.vars[name] = var
        ttk.Scale(row, from_=lo, to=hi, variable=var).pack(side="left", fill="x", expand=True, padx=6)
        ent = ttk.Entry(row, width=8, justify="right")
        ent.pack(side="right")
        ent.insert(0, f"{var.get():.2f}")
        var.trace_add("write", lambda *_a, e=ent, v=var: self.sync_entry(e, v))
        ent.bind("<Return>", lambda _e, n=name, e=ent: self.from_entry(n, e))
        ent.bind("<FocusOut>", lambda _e, n=name, e=ent: self.from_entry(n, e))

    def sync_entry(self, entry: ttk.Entry, var: tk.DoubleVar, hz: bool = False) -> None:
        try:
            val = var.get()
        except tk.TclError:
            return
        new = f"{val:g}" if hz else f"{val:.2f}"
        if entry.get() != new:
            entry.delete(0, "end")
            entry.insert(0, new)

    def from_entry(self, name: str, entry: ttk.Entry) -> None:
        try:
            self.vars[name].set(float(entry.get()))
        except ValueError:
            pass

    def values(self) -> dict[str, float]:
        return {k: float(v.get()) for k, v in self.vars.items()}

    def load_preset(self, name: str) -> None:
        for k, val in PRESETS[name].items():
            if k in self.vars:
                self.vars[k].set(val)
        self.status.configure(text=f"Loaded preset: {name} (not applied yet)")

    def reload_file(self) -> None:
        vals = parse_conf(CONF.read_text())
        for k, var in self.vars.items():
            if k in vals:
                var.set(vals[k])
        self.status.configure(text="Reloaded from conf (not restarted)")

    def apply(self) -> None:
        vals = self.values()
        # Keep centers strictly increasing for sanity
        hz_keys = [f"Band {i} Freq (Hz)" for i in range(1, 7)]
        prev = 20.0
        for k in hz_keys:
            v = max(vals[k], prev * 1.05)
            vals[k] = v
            self.vars[k].set(v)
            prev = v
        try:
            write_conf(CONF, vals)
        except Exception as e:
            messagebox.showerror("Write failed", str(e))
            return
        ok, msg = restart_service()
        if ok:
            self.status.configure(text=f"Applied → {SERVICE} {msg}")
        else:
            messagebox.showerror("Restart failed", msg)


def main() -> int:
    app = Tuner()
    if app.winfo_exists():
        app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
