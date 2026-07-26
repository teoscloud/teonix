# Handover: integrate EEDN into the NixOS flake

**Audience:** custom flake agent / NixOS module author  
**Source tree:** `Projects/Personal/easyeffectsdenoiser`  
**Goal:** On login, PCM2902 mic audio is **always** denoised via EEDN and handed to Easy Effects — **not** the raw `pcm2902-listen` loopback.

---

## 1. What this project is

Zero-latency, time-domain (no FFT) 6-band downward-expander denoiser (Bertom Classic–style).

| Artifact | Role |
|----------|------|
| `eedn_denoiser.so` (LADSPA) | Used by PipeWire `filter-chain` (primary path) |
| `eedn.lv2` (LV2) | Optional (Carla/DAW); not required for autostart |
| `pipewire/eedn-pcm2902-mic.conf` | Filter graph: capture PCM2902 → LADSPA → Easy Effects |
| `systemd/eedn-pcm2902.service` | User unit that runs that filter-chain |
| `gui/eedn_tuner.py` | Optional GUI to edit controls + restart unit |

**Live signal chain (desired):**

```text
alsa_input…PCM2902…analog-stereo-input
  → EEDN LADSPA (eedn_denoiser)
  → easyeffects_sink
  → (Easy Effects output device, e.g. Scarlett)
```

**Must replace / disable:**

```text
pcm2902-listen.service   # NixOS user unit: raw pw-loopback, NO denoise
```

That unit currently appears as Playback stream **“PCM2902 output”** and was being stolen by Easy Effects. It must not run alongside EEDN.

---

## 2. Current tuned controls (ship these as defaults)

Preset name: **`default`**. Live tuner session on PCM2902. Keep in the
filter-chain `control = { }` block (`pipewire/eedn-pcm2902-mic.conf`):

| Control | Value |
|---------|------:|
| Threshold (dB) | **-71.4583** |
| Range Band 1 (dB) | 12.0 |
| Range Band 2 (dB) | 11.5 |
| Range Band 3 (dB) | 8.0 |
| Range Band 4 (dB) | 14.0 |
| Range Band 5 (dB) | 12.5115 |
| Range Band 6 (dB) | 8.8918 |
| Band 1 Freq (Hz) | 120 |
| Band 2 Freq (Hz) | 240 |
| Band 3 Freq (Hz) | 600 |
| Band 4 Freq (Hz) | 1580 |
| Band 5 Freq (Hz) | 3000 |
| Band 6 Freq (Hz) | 12000 |
| HF Bias | 0.4 |
| Stereo Link | 0.9 |
| Bypass | 0.0 |

Notes: `presets/default.md` (band rationale in `presets/pcm2902_measured.md`).

**Hardware node names (verify on machine if USB path changes):**

- Capture: `alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo-input`
- Playback target: `easyeffects_sink`

---

## 3. Flake integration checklist

### A. Package the plugin

Create a derivation (suggested pname `eedn-denoiser`) from this repo:

- **Build inputs:** `lv2`, `pkg-config` (native), `gcc`, `gnumake`
- **Build:** `make` (produces `build/eedn_denoiser.so` + `build/eedn.lv2/`)
- **Install:**
  - `$out/lib/ladspa/eedn_denoiser.so`
  - `$out/lib/lv2/eedn.lv2/{eedn.so,manifest.ttl,eedn.ttl}`
- Existing `flake.nix` / `Makefile` `PREFIX` install can be adapted; prefer store paths over `$HOME/.local`.

### B. Install PipeWire filter-chain config

Install a rewritten copy of `pipewire/eedn-pcm2902-mic.conf` to something like:

- `/etc/pipewire/filter-chain.conf.d/eedn-pcm2902-mic.conf`  
  **or** user: still OK under `${config.xdg.configHome}/pipewire/filter-chain.conf.d/` via Home Manager

**Critical:** LADSPA must resolve `eedn_denoiser`. Prefer setting in the systemd unit:

```systemd
Environment=LADSPA_PATH=${eedn-denoiser}/lib/ladspa
```

Do **not** rely on a bare `plugin = eedn_denoiser` without `LADSPA_PATH` pointing at the store.

Keep `plugin = eedn_denoiser` and `label = eedn_denoiser` (LADSPA label).

### C. User systemd service (replace home-dir hack)

Ship a NixOS/Home-Manager **user** service equivalent to `systemd/eedn-pcm2902.service`, but with store paths:

```systemd
[Unit]
Description=EEDN denoise for PCM2902 mic → Easy Effects
After=pipewire.service pipewire-pulse.service easyeffects.service
Wants=pipewire.service
BindsTo=pipewire.service
Conflicts=pcm2902-listen.service

[Service]
Type=simple
Environment=LADSPA_PATH=${eedn-denoiser}/lib/ladspa
Environment=LV2_PATH=${eedn-denoiser}/lib/lv2
ExecStartPre=-${pkgs.systemd}/bin/systemctl --user stop pcm2902-listen.service
ExecStart=${pkgs.pipewire}/bin/pipewire -c ${eednPcm2902Conf}
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
```

Enable for the user: `systemd.user.services.eedn-pcm2902.enable = true` (or HM `systemd.user.services`).

### D. Disable / remove `pcm2902-listen`

In the flake that currently defines `pcm2902-listen.service`:

1. **Remove** that user service from the NixOS config, **or**
2. Set it `enable = false` and ensure it is not `WantedBy=pipewire.service`.

Also add `Conflicts=pcm2902-listen.service` on the EEDN unit (already above).

If the unit remains in the system closure for a while, masking is a temporary bridge — prefer deleting the module.

### E. Easy Effects

Keep Easy Effects autostart as today. EEDN playback targets `easyeffects_sink`.  
Do **not** point Easy Effects Output Device at the PCM2902 DAC for this mic-listen path (EE output stays on Scarlett/etc.).

### F. Optional: tuner GUI

Package `gui/eedn_tuner.py` only if wanted. Today it edits  
`~/.config/pipewire/filter-chain.conf.d/eedn-pcm2902-mic.conf`  
and restarts `eedn-pcm2902.service`. After flake integration, either:

- point the tuner at the HM-managed conf path, or  
- drop the GUI and change controls via Nix options / rebuild.

---

## 4. Suggested NixOS / HM option sketch

```nix
# Illustrative — adapt to the flake’s module style
options.services.eednPcm2902 = {
  enable = mkEnableOption "EEDN denoised PCM2902 mic → Easy Effects";
  thresholdDb = mkOption { type = types.float; default = -71.4583; };
  # … optional overrides for ranges / band Hz …
};

# When enable = true:
#  - build eedn-denoiser package
#  - write filter-chain conf (substitute controls from options)
#  - enable systemd.user.services.eedn-pcm2902
#  - ensure pcm2902-listen is disabled
```

---

## 5. Files the agent should read

| Path | Why |
|------|-----|
| `Makefile` | Build/install layout |
| `src/dsp.c`, `src/ladspa_plugin.c` | LADSPA port names (must match conf keys) |
| `pipewire/eedn-pcm2902-mic.conf` | Exact filter-chain graph + control names |
| `systemd/eedn-pcm2902.service` | Unit semantics |
| `presets/default.md` | Ship-as-default control values |
| `presets/pcm2902_measured.md` | Band layout / measurement rationale |
| `flake.nix` / `shell.nix` | Existing nix packaging hints |

**Do not** use `pipewire/eedn-denoise-sink.conf` for this mic path — that was an alternate “apps → DAC” experiment.

---

## 6. Verification after rebuild

```bash
systemctl --user is-active eedn-pcm2902.service     # active
systemctl --user is-active pcm2902-listen.service    # inactive / missing
pw-dump | grep -E 'eedn_pcm2902|pcm2902-mic-listen'

# Expect nodes:
#   eedn_pcm2902_capture  → PCM2902 input
#   eedn_pcm2902_playback → easyeffects_sink
# Expect NOT:
#   output.pcm2902-mic-listen
```

In pavucontrol **Playback**: `EEDN PCM2902 (denoised)` → `Easy Effects Sink`.

---

## 7. Cleanup of today’s manual install (after flake owns it)

Once the flake ships the package + unit + conf:

```bash
systemctl --user disable --now eedn-pcm2902.service
rm -f ~/.config/systemd/user/eedn-pcm2902.service
# keep or remove ~/.config/pipewire/filter-chain.conf.d/eedn-pcm2902-mic.conf
# (prefer flake-managed path only — avoid duplicates)
rm -f ~/.local/lib/ladspa/eedn_denoiser.so
systemctl --user daemon-reload
```

Unmask only if you intentionally bring back raw listen:

```bash
systemctl --user unmask pcm2902-listen.service
```

---

## 8. Non-goals / constraints

- Easy Effects **cannot** load arbitrary LV2/LADSPA in its effect list; PipeWire filter-chain is the correct integration.
- Plugin is **not** RNNoise / DeepFilter; it is multiband expansion (good for game/movie + this USB mic path).
- Zero algorithmic latency (IIR); do not add FFT denoisers in this unit without an explicit new design.

---

## 9. One-line success criterion

**On every boot/login, speaking into the PCM2902 goes through EEDN into Easy Effects automatically, and `pcm2902-listen` never appears.**
