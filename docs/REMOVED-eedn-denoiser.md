# Removed: eedn-denoiser (do not restore)

**Status:** Permanently removed from Teonix. Do **not** reintroduce.

EEDN / `eedn-pcm2902` was a PCM2902 mic → LADSPA denoise → Easy Effects PipeWire path.
Mic denoise / mixer work continues in **BusChain Control** (`~/Projects/buschain-control`), not in this flake.

## Deleted from the repo

- `vendor/eedn-denoiser/`
- `modules/apps/eedn-denoiser.nix`
- `modules/services/eedn-pcm2902.nix`
- `home/hosts/nixbox/dotfiles/config/hypr/scripts/waybar-eedn-volume.sh`

## Clean local leftovers (run once on each machine)

```bash
systemctl --user disable --now eedn-pcm2902.service 2>/dev/null || true
rm -f ~/.config/systemd/user/eedn-pcm2902.service
rm -f ~/.config/pipewire/filter-chain.conf.d/eedn-*.conf
rm -f ~/.local/lib/ladspa/eedn_denoiser.so
rm -rf ~/.local/lib/lv2/eedn.lv2 ~/.config/eedn
pkill -f 'pipewire -c.*eedn' 2>/dev/null || true
```

Then rebuild (`nixupgrade`) so any store packages drop out of the closure.
