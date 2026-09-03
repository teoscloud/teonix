# applenix on Asahi Fedora

Fedora owns the kernel, Mesa/Asahi GPU, firmware, PipeWire, and a display manager. Nix owns Hyprland, the rice, and almost every package. **Fedora does not ship Nix** — the bootstrap installs it.

One command as your normal user (not root):

```bash
curl -fsSL https://raw.githubusercontent.com/teoscloud/teonix/main/hosts/applenix/fedora.sh | bash
```

That installs the Nix daemon (Determinate), `git` if missing, clones teonix, and switches Home Manager to `#applenix-fedora`. It is idempotent: if anything fails, run the same command again.

Then log out and pick **Hyprland (Nix)**.

The NixOS USB path (`install.sh`, `#applenix`) is unchanged.

---

## What the script does

| Step | Does |
|------|------|
| `nix` | installs multi-user Nix with flakes if `nix` is not on the system |
| `git` | `sudo dnf install -y git` if needed |
| `repo` | clones or fast-forwards `~/teonix` |
| `identity` | writes `local-identity.nix` from the current login (`$USER`) |
| `switch` | `nix run nixpkgs#home-manager -- switch --flake path:.#applenix-fedora` |
| `session` | copies the wayland session file to `/usr/share/wayland-sessions/` so GDM lists it |

```bash
curl …/fedora.sh | bash -s status    # checklist
curl …/fedora.sh | bash -s help
```

The login that runs the script is the Home Manager user. `teodor` is only the fallback when nothing is set (this machine). Override with `TEONIX_USER=` if needed. That writes gitignored `local-identity.nix` (`username`, `homeDirectory`, `projectdir`).

Other overrides: `TEONIX_DIR=`, `TEONIX_REPO=`, `FORCE=1`.

---

## Fedora keeps

- kernel + Asahi modules
- Mesa / Asahi GPU userspace (`/usr/lib64/dri`)
- PipeWire + WirePlumber
- display manager
- Wi-Fi / vendor firmware

Do not replace Mesa or PipeWire with Nix copies. Everything else — Hyprland, Quickshell, hyprflow, browsers, fonts, portals — comes from Nix.

---

## After the first switch

Later updates (in a shell that has sourced Nix, or a new login):

```bash
updatehome
```

`systemupdate` here is `nix flake update` + the same Home Manager switch. There is no `nixos-rebuild`.

If you just installed Nix in this terminal and `nix` is missing, either open a new terminal or:

```bash
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
```

---

## Check

| What | How |
|------|-----|
| GPU | `glxinfo \| grep renderer` or `vulkaninfo` — Apple/Asahi, not llvmpipe |
| Audio | Fedora PipeWire; Nix `pavucontrol` uses `/run/user/$UID/pipewire-0` |
| Hyprland | greeter → Hyprland (Nix) |
| Quickshell | bar on the built-in panel |

If the compositor is software-rendered, Fedora Mesa is missing or the session did not export `LIBGL_DRIVERS_PATH`.
