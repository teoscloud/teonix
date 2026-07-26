# EEDN Multiband Denoiser

Zero-latency, **time-domain** (no FFT) 6-band downward-expander denoiser inspired by [Bertom Denoiser Classic](https://bertomaudio.com/denoiser-classic.html). Built for Linux playback of games and movies: reduces hiss/hum/room tone without spectral smearing or heavy EQ damage.

## Important: Easy Effects limitation

Easy Effects is **not** a generic LV2 host — it only exposes a curated set of plugins with hand-written UIs. You **cannot** drop this plugin into Easy Effects’ effect list.

What this project provides instead (same PipeWire stack Easy Effects uses):

1. **LV2** — use in Carla, Ardour, REAPER, etc.
2. **LADSPA** — use in a PipeWire `filter-chain` virtual sink (recommended for games/movies)
3. You can still run **Easy Effects** on the same device chain (EQ, compressor, etc.) while this sink does Bertom-style NR

## Build (Nix)

Because this folder may live inside a larger git tree, prefer `nix-shell` (tracks local files without requiring `git add`):

```bash
cd easyeffectsdenoiser
nix-shell
make
make smoke          # offline DSP sanity check
./scripts/install.sh
```

One-shot:

```bash
nix-shell --run ./scripts/install.sh
```

If you use flakes (`nix develop`), either `git add` this directory first or keep using `nix-shell`.

Installs to `~/.local/lib/lv2/eedn.lv2` and `~/.local/lib/ladspa/eedn_denoiser.so`.

## Run as a PipeWire sink (game/movie path)

```bash
nix-shell --run ./scripts/run-sink.sh
```

Then set output device to **EEDN Denoiser Sink** (pavucontrol / Plasma Audio / `wpctl`).

Tune controls in `pipewire/eedn-denoise-sink.conf` (`Threshold`, per-band `Range`, `HF Bias`, `Stereo Link`), then restart the sink process.

## Autostart (login)

Already wired as a user systemd service. To (re)enable:

```bash
./scripts/enable-autostart.sh
```

That will:
1. Install/sync the PipeWire filter-chain config + unit
2. **Mask** NixOS `pcm2902-listen.service` (raw undenoised loopback)
3. **Enable** `eedn-pcm2902.service` so every login gets: PCM2902 mic → EEDN → Easy Effects

## Tuner GUI

```bash
nix-shell --run ./scripts/tuner.sh
```

Sliders write `~/.config/pipewire/filter-chain.conf.d/eedn-pcm2902-mic.conf` and restart `eedn-pcm2902.service`. Default preset is **`default`** (live PCM2902 tune); also includes UserTuned, PCM2902 Measured, Mac Bertom, Gentle.

## Controls (Bertom-like)

| Control | Role |
|--------|------|
| **Threshold** | Noise detection level. Raise toward `0` for more NR; lower toward `-140` for less. |
| **Range Band 1–6** | Max gain reduction (dB) per band. Higher = more cut when below threshold. |
| **HF Bias** | Lets HF harmonics/transients through more easily (above ~1 kHz). |
| **Stereo Link** | Link L/R envelopes (`0` independent … `1` fully linked). |
| **Freq Low/High** | Processing range; bands are log-spaced inside (LV2). |
| **HPF/LPF** | Optional hard cut outside the processing range (LV2). |

Defaults are gentle for games/movies (less mid ducking, more hiss-band reduction).

## Architecture

- Linkwitz–Riley 4th-order crossover tree → 6 bands
- Per-band envelope follower + soft-knee downward expander
- Max reduction clamped by band **Range** (like Bertom’s sliders)
- True zero algorithmic latency (IIR only; no FFT lookahead)

## License

MIT — independent reimplementation; not affiliated with Bertom Audio.
