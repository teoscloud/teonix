# PCM2902 Measured preset

Captured silent input from
`alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo-input`
(~10 s, 48 kHz stereo).

## Findings

| Metric | Value |
|--------|------:|
| RMS noise floor | ≈ **-86.5 dBFS** |
| Peak (noise) | ≈ **-71.7 dBFS** |
| Spectral tilt | ≈ **-7 dB / decade** (pink-ish) |

Notable structure:

- Strong **mains-related** energy (50 Hz and especially **120 / 240 / 360 Hz**)
- Dominant tonal peak near **1579 Hz** (highest prominence in the capture)
- Broadband energy hump roughly **1.2–4 kHz**
- HF (7–16 kHz) present but lower than the mid hump

## Preset mapping

| Band | Hz | Range (dB) | Why |
|-----:|---:|-----------:|-----|
| 1 | 120 | 12.0 | hum / 2nd harmonic region |
| 2 | 240 | 11.5 | strong hum harmonic |
| 3 | 600 | 8.0 | quieter mid |
| 4 | 1580 | 14.0 | strongest measured tone |
| 5 | 3000 | 12.5 | 2–4 kHz codec/hash cluster |
| 6 | 12000 | 10.0 | air / hiss |
| Threshold | | **-69.0** | user-tuned after measured band layout |

Re-run analysis anytime with a silent device:

```bash
nix-shell -p 'python3.withPackages (ps: with ps; [ numpy scipy ])' \
  --run 'pw-record --target=alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo-input --rate=48000 --channels=2 --format=f32 /tmp/pcm2902_noise.raw'
```

Then convert/analyze as in the project history / tuner notes.

**Note:** The older “Gentle” preset was a generic starting point and was **not** derived from this capture.
