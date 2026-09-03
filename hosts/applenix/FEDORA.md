# applenix on Asahi Fedora

Fedora owns the kernel, Mesa/Asahi GPU, firmware, PipeWire, and a display manager. Nix owns Hyprland, the rice, and almost every package.

The NixOS install path (`install.sh`, `#applenix`) is unchanged. This is the userspace target: `homeConfigurations.applenix-fedora`.

## 1. Fedora

Install [Asahi Fedora](https://asahilinux.org/fedora/) the usual way. Keep its GPU stack, PipeWire, and greeter (GDM or SDDM). Do not replace Mesa or PipeWire with Nix copies.

## 2. Nix

Multi-user Nix with flakes. Determinate or the official installer:

```bash
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
# or: https://nixos.org/download.html
```

Confirm `experimental-features = nix-command flakes` in `/etc/nix/nix.conf` (Determinate sets this).

## 3. Switch

```bash
git clone https://github.com/teoscloud/teonix.git ~/teonix
cd ~/teonix
nix run nixpkgs#home-manager -- switch -b bak --flake path:.#applenix-fedora
```

Later updates are `updatehome` (or `systemupdate`, which is flake update + the same switch). There is no `nixos-rebuild`.

## 4. Session

Home Manager writes `~/.local/share/wayland-sessions/hyprland-nix.desktop`. SDDM usually lists **Hyprland (Nix)** from there. GDM often only looks in `/usr/share/wayland-sessions/`:

```bash
sudo mkdir -p /usr/share/wayland-sessions
sudo cp ~/.local/share/wayland-sessions/hyprland-nix.desktop /usr/share/wayland-sessions/
```

Log out, pick **Hyprland (Nix)**. The session script points GL/EGL/GBM at Fedora’s `/usr/lib64` so Nix Hyprland can use the Asahi GPU.

## Fedora keeps

- kernel + Asahi modules
- Mesa / Asahi GPU userspace (`/usr/lib64/dri`)
- PipeWire + WirePlumber
- display manager
- Wi-Fi / vendor firmware

Everything else — Hyprland, Quickshell, hyprflow, browsers, fonts, portals — comes from Nix.

## Check

| What | How |
|------|-----|
| GPU | `glxinfo \| grep renderer` or `vulkaninfo` — should name Apple/Asahi, not llvmpipe |
| Audio | Fedora PipeWire; `pavucontrol` from Nix talks to `/run/user/$UID/pipewire-0` |
| Hyprland | greeter → Hyprland (Nix) |
| Quickshell | bar on the built-in panel |

If the compositor falls back to software rendering, Fedora Mesa is missing or the session did not export `LIBGL_DRIVERS_PATH`. Do not install Nix `mesa` into the session PATH ahead of `/usr`.
