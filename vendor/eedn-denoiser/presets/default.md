# default preset

Ship-as-default PCM2902 → EEDN → Easy Effects controls, captured from the
live filter-chain (`~/.config/pipewire/filter-chain.conf.d/eedn-pcm2902-mic.conf`).

Same band centers as `pcm2902_measured.md`, with the later live threshold /
band-5 / band-6 tweaks.

| Control | Value |
|---------|------:|
| Threshold (dB) | **-71.4583** |
| Range Band 1 (dB) | 12.0 |
| Range Band 2 (dB) | 11.5 |
| Range Band 3 (dB) | 8.0 |
| Range Band 4 (dB) | 14.0 |
| Range Band 5 (dB) | 12.5115 |
| Range Band 6 (dB) | 8.8918 |
| Band 1–6 Freq (Hz) | 120 / 240 / 600 / 1580 / 3000 / 12000 |
| HF Bias | 0.4 |
| Stereo Link | 0.9 |
| Bypass | 0.0 |
| Gate Enable | 1 |
| Gate Threshold (dB) | **-78.0** |
| Gate Hysteresis (dB) | 3.0 |
| Gate Attack / Hold / Release (ms) | 2 / 80 / 120 |
| Gate Range (dB) | 100 (mute) |

Gate calibrated to **denoised** idle at 100% playback volume
(peak ≈ −80 dBFS, p99 ≈ −81). Opens a few dB above residual so
only-noise playback is silenced; real content opens the gate.

Wired as:

- Tuner GUI preset name: **`default`** (`gui/eedn_tuner.py`)
- PipeWire template: `pipewire/eedn-pcm2902-mic.conf`
- NixOS seed: `modules/services/eedn-pcm2902.nix`
