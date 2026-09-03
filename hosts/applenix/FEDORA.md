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
| `session` | one-time: trampoline at `/usr/local/bin/hyprland-nix-session` + SDDM session dir (no more `sudo cp`) |

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

Later updates, from any new zsh or bash login (aliases live in `~/.zshaliases.sh` and `~/.bashrc.d/teonix-aliases.sh`):

| Command | Does |
|---------|------|
| `updatehome` / `rebuild` / `nixupgrade` | `home-manager switch --flake path:.#applenix-fedora` |
| `nixupdate` | `nix flake update` only |
| `systemupdate` | flake update + switch |
| `hm-gens` / `hm-rollback` | Home Manager generations |
| `nixclean` | drop old HM generations and GC |

There is no `nixos-rebuild`. Extra flags pass through (`updatehome --show-trace`). `path:.` means untracked files in the checkout are included.

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

If the compositor is software-rendered, Fedora Mesa is missing or the session did not wrap host libEGL.

### Instant return to SDDM

The session died before the first frame. On a TTY (Ctrl+Alt+F3):

```bash
cat ~/.local/state/hyprland-nix-session.log
```

Typical causes this config already guards: a hardcoded panel mode Asahi DCP rejects, Nix Mesa loading Fedora’s `asahi_dri.so` without Fedora’s libEGL, or picking a stock **Hyprland** entry whose `Exec=Hyprland` is not on SDDM’s PATH.

After pulling the fix:

```bash
cd ~/teonix && git pull
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
# once: writable session dir + trampoline (fedora.sh session step)
FORCE=1 bash ~/teonix/hosts/applenix/fedora.sh
```

`fedora.sh`’s `session` step is the only sudo. After that, `updatehome` refreshes `~/.nix-profile/bin/hyprland-nix-session`; the greeter always execs `/usr/local/bin/hyprland-nix-session`. No more `sudo cp` of `.desktop` files.

Then log in again. Either **Hyprland** or **Hyprland (Nix)** starts the same wrapper.
