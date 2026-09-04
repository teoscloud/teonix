# applenix on Asahi Fedora

Fedora owns the kernel, Mesa/Asahi GPU, firmware, PipeWire, and a display manager. Nix owns Hyprland, the rice, and almost every package. **Fedora does not ship Nix** — the bootstrap installs it.

One command as your normal user (not root):

```bash
curl -fsSL https://raw.githubusercontent.com/teoscloud/teonix/main/hosts/applenix/fedora.sh | bash
```

That installs the Nix daemon (Determinate), `git` if missing, clones teonix, and switches Home Manager to `#applenix-fedora`. It is idempotent: if anything fails, run the same command again.

Then reboot and log in at **GDM**. Pick **Hyprland (Nix)** if it is not already selected.

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
| `gpu` | `sudo non-nixos-gpu-setup` — points `/run/opengl-driver` at Nix Mesa (see GPU below) |
| `keyring` | host `gnome-keyring` + `authselect with-pam-gnome-keyring` so the greeter unlocks secrets |
| `session` | trampoline + **GDM** (not Plasma Login, SDDM, or greetd) |
| `steam` | **opt-in** — `dnf install steam` (muvm + FEX + Mesa overlays). Not run by `all`. |

```bash
curl …/fedora.sh | bash -s status    # checklist
curl …/fedora.sh | bash -s help
bash ~/teonix/hosts/applenix/fedora.sh steam   # named step
```

The login that runs the script is the Home Manager user. `teodor` is only the fallback when nothing is set (this machine). Override with `TEONIX_USER=` if needed. That writes gitignored `local-identity.nix` (`username`, `homeDirectory`, `projectdir`).

Other overrides: `TEONIX_DIR=`, `TEONIX_REPO=`, `FORCE=1`.

---

## GPU: Nix apps use Nix Mesa, not Fedora's

This is the one thing to get right, and it is the opposite of what it looks like.

Nix Hyprland, kitty and Quickshell are linked against **Nix** libglvnd/Mesa. Upstream Mesa ships the Asahi gallium driver, so Nix Mesa drives this GPU natively — `glxinfo`-equivalent reports `Mesa 26.x`, GL 4.6, hardware. Fedora's `/usr/lib64` copies are never needed by Nix apps.

**Do not put `/usr/lib64` on `LD_LIBRARY_PATH` to "share" Fedora's drivers.** The Nix loader then picks host `libEGL`, which cannot resolve Nix `libexpat`, and Hyprland dies before the first frame (`error while loading shared libraries: libexpat.so.1`). Symptom: instant return to SDDM.

Nix finds its drivers through `/run/opengl-driver`, created by the `gpu` step (Home Manager's `targets.genericLinux.gpu`, enabled by default here):

```bash
sudo ~/.nix-profile/bin/non-nixos-gpu-setup
```

It installs a `tmpfiles.d` entry, so the symlink returns on every boot. `updatehome` warns when it drifts:

> GPU drivers require an update, run `sudo …/non-nixos-gpu-setup`

Re-run `bash ~/teonix/hosts/applenix/fedora.sh` and the `gpu` step fixes it. Fedora's own apps are unaffected — nothing outside Nix looks at `/run/opengl-driver`.

`hyprland-nix-session` additionally exports `LIBGL_DRIVERS_PATH`, `GBM_BACKENDS_PATH` and `__EGL_VENDOR_LIBRARY_FILENAMES` from the current generation's driver set, so the compositor comes up even before the `gpu` step has run.

Two details worth knowing:

- GBM backends live in `<mesa>/lib/gbm`, not `<mesa>/lib`. Pointing `GBM_BACKENDS_PATH` at `lib` gives `MESA-LOADER: failed to open dri: …/dri_gbm.so` followed by `CBackend::create() failed!`.
- The greeter execs `Hyprland`, not `start-hyprland`. The latter hard-refuses on non-NixOS unless nixGL is installed, which is a black screen with only a line in the session log.

This Mac splits render and display across two DRM devices — `card*` with the `asahi` driver is render-only (no connectors) and `apple-drm` is the KMS device holding `eDP-1`. Aquamarine picks the KMS one on its own; do not pin `AQ_DRM_DEVICES` to it, or rendering loses the GPU.

---

## Secrets: GNOME Keyring only, never KWallet

Nixbox does this at the NixOS level (`services.gnome.gnome-keyring` + PAM). Fedora has to do the same with the **host** daemon, because only `/usr/lib64/security/pam_gnome_keyring.so` can unlock the login keyring at SDDM.

KDE's `ksecretd` is started by Plasma PAM and stays on the user bus after you switch to Hyprland. Chromium then either talks to KWallet or finds no `org.freedesktop.secrets` — that is the "keyring missing / failed to unlock" popup. teonix:

- installs host `gnome-keyring` + `gnome-keyring-pam` (`fedora.sh` `keyring` step)
- enables `authselect` feature `with-pam-gnome-keyring` (session `auto_start`)
- puts `pam_gnome_keyring.so` **after** the `system-auth` substack in `/etc/pam.d/login` and `/etc/pam.d/greetd` — authselect leaves it *inside* that substack after `auth sufficient pam_unix`, so a correct password never reaches the keyring, `login.keyring` stays locked, and Brave shows “The login keyring did not get unlocked when you logged into your computer”
- claims `org.freedesktop.secrets` from the user session (`teonix-secrets-ensure`)
- disables KWallet (`kwalletrc` `Enabled=false`) and no-ops `plasma-kwallet-pam`
- points the Secret portal at `gnome-keyring`
- wraps Brave / Chromium / Chrome / Mailspring with `--password-store=gnome-libsecret`

If that Brave dialog is on screen **now**, Unlock it once with your **login** password — the keyring file is not lost. Then:

```bash
bash ~/teonix/hosts/applenix/fedora.sh keyring
bash ~/teonix/hosts/applenix/fedora.sh session
sudo reboot
```

After a GDM (or TTY) password login, the keyring unlocks with PAM. No popup, same `login.keyring`.

---

## Fedora keeps

- kernel + Asahi modules
- PipeWire + WirePlumber
- display manager (teonix uses GDM; Plasma Login / SDDM / greetd are not used)
- Wi-Fi / vendor firmware

Do not replace PipeWire with a Nix copy. Everything else — Hyprland, Quickshell, hyprflow, browsers, fonts, portals — comes from Nix, and Nix apps render with Nix Mesa (see GPU above), not Fedora's.

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

### Gray / black screen at boot, or a login box that flashes then dies

That is the **login manager**, not Hyprland.

- **Plasma Login** (`plasmalogin`): kwin starts, greeter SIGSEGVs in layer-shell on Asahi DCP → cursor only.
- **SDDM** on this host: no theme installed → same.
- **greetd/tuigreet**: died here with `configured default session user 'greeter' not found` → gray VT, no cursor.

teonix uses **GDM** (mutter greeter, `gdm-password` PAM). No KDE stack.

```bash
bash ~/teonix/hosts/applenix/fedora.sh session
sudo reboot
```

Log in at GDM. Gear menu → **Hyprland (Nix)** if needed. Do not start GDM while Hyprland is already running from a TTY.

### Instant return to the greeter after typing the password

The session died before the first frame. On a TTY (Ctrl+Alt+F3):

```bash
cat ~/.local/state/hyprland-nix-session.log
```

The log always ends on the reason. Causes this config already guards, with the line each one prints:

| Log line | Cause |
|----------|-------|
| `XCURSOR_PATH: unbound variable` | `set -u` while sourcing `hm-session-vars.sh`; the wrapper now sources it under `set +u` |
| `libexpat.so.1: cannot open shared object file` | Fedora `libEGL` won via `LD_LIBRARY_PATH`; Nix apps must use Nix Mesa |
| `failed to open dri: …/dri_gbm.so` + `CBackend::create() failed!` | `GBM_BACKENDS_PATH` missing the `/gbm` suffix |
| `requires nixGL to be installed` | `start-hyprland` off NixOS; exec `Hyprland` directly |
| nothing after `exec Hyprland` | genuine compositor problem — read `/run/user/$UID/hypr/*/hyprland.log` |

A hardcoded panel mode Asahi DCP rejects does the same thing, which is why the monitor line is `monitor = , preferred, auto, 1`.

After pulling the fix:

```bash
cd ~/teonix && git pull
. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
bash ~/teonix/hosts/applenix/fedora.sh
```

The `gpu`, `session`, `keyring`, and opt-in `steam` steps use sudo. After that, `updatehome` refreshes `~/.nix-profile/bin/hyprland-nix-session`; the greeter always execs `/usr/local/bin/hyprland-nix-session`. No more `sudo cp` of `.desktop` files.

Then reboot and log in at **GDM**. Either **Hyprland** or **Hyprland (Nix)** starts the same wrapper.

---

## Steam (Fedora Asahi wrapper, not Nix Steam)

Do not install Nixpkgs Steam or a random Proton build. On this Mac the supported stack is Fedora’s `steam` RPM: a launcher that starts **muvm** (4K-page guest) + **FEX** + Mesa x86 overlays, then Steam / Proton / DXVK on the Asahi GPU.

```bash
bash ~/teonix/hosts/applenix/fedora.sh steam
updatehome
steam
```

`teonix-steam` (and the `steam` command / desktop entry) start **one** muvm, take a flock, and after the first bootstrap run `~/.local/share/Steam/steam.sh` — not `bin_steam.sh` and not `-cef-force-occlusion` (those two were the restart loop). Fedora’s PyQt splash is skipped: its window probe never matches current Steam titles, so closing the splash killed the guest. A second launch — hyprflow restore, `steam://` on the host, or clicking Steam again — used to spawn another VM. If Steam is already up, the wrapper exits 0.

Logs: `~/.local/state/teonix-steam.log`. If it wedges:

```bash
teonix-steam-kill
steam
```

### Battle.net (`teonix-battlenet`, no Steam client)

Host Lutris + Nix **aarch64** GE-Proton cannot run the Battle.net installer (Proton #10011: `RPC_S_SERVER_UNAVAILABLE` busy-loop, dead language window). x86 Proton cannot run on the 16K host (`jemalloc`). The working stack is the same **muvm (4K guest) + FEX** the Steam RPM pulls in — without launching Steam.

```bash
bash ~/teonix/hosts/applenix/fedora.sh steam   # muvm + FEX only; skip if already done
updatehome
# Windows x86 installer from blizzard.com → ~/Downloads/Battle.net-Setup.exe
teonix-steam-kill    # one muvm on this machine
teonix-battlenet
```

First run downloads **GE-Proton11-5-x86_64** (~510 MiB, checksummed; never the `-aarch64` tarball), then runs setup with `--lang=enUS` so the hung language dialog never appears. After `Battle.net.exe` exists, the script writes `~/.local/share/applications/battlenet.desktop` and starts the client with Blizzard `HardwareAcceleration=false`, `--in-process-gpu`, and `--disable-gpu-compositing` (never `--disable-gpu`, never WineD3D, never SwiftShader on this Air). DXVK stays on for games. Later launches are the client only.

```bash
battlenet          # same as teonix-battlenet
bnetkill           # teonix-battlenet-kill
```

Logs: `~/.local/state/teonix-battlenet.log`. Prefix: `~/.local/share/teonix/battlenet/`. Do not write `~/.fex-emu/Config.json`. Do not pick Proton Experimental (ARM64). Close browsers first — this Air has 8 GB. If the kernel OOM-kills the guest:

```bash
sudo /usr/libexec/fedora-asahi-remix-scripts/setup-swap.sh --recreate 16G
```
