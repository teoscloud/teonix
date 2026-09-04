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
- The greeter execs `start-hyprland --no-nixgl` (Hyprland 0.53+ watchdog). `--no-nixgl` is required: without it, Nix Hyprland off NixOS refuses unless nixGL is on `PATH`, which is a black screen with only a line in the session log. Mesa is already wired by the exports above and `/run/opengl-driver`.

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
| `requires nixGL to be installed` | `start-hyprland` ran without `--no-nixgl` and `/run/opengl-driver` is missing |
| nothing after `exec start-hyprland` | genuine compositor problem — read `/run/user/$UID/hypr/*/hyprland.log` |

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

### Battle.net + WoW Classic (one muvm)

Host Lutris + Nix **aarch64** GE-Proton cannot run Battle.net (Proton #10011). x86 Proton cannot run on the 16K host (`jemalloc`). The stack is **one 4K muvm + FEX + x86 GE-Proton11-5**. Battle.net, `teonix-wow`, WowUp, and Steam share `$XDG_RUNTIME_DIR/teonix-muvm.lock` — they must not overlap. Scale stays **1.6**. Do not change CEF flags (`--disable-gpu` is a black HWND; WineD3D crashes; SwiftShader never starts `login.app`).

One command. Log in in the Battle.net window, then click Play. Nothing opens a browser.

```bash
teonix-battlenet-kill
bnet
```

Do not start Steam or WowUp at the same time.

```bash
bnet / wow         # same thing: Battle.net, then Play for Classic
bnetkill           # stop the guest
bnetdoctor         # managed settings + last launch verdicts
bnetlog            # follow the session log
wownolauncher      # boot the launcher and press Play for you
```

First Battle.net run downloads **GE-Proton11-5-x86_64** (~510 MiB, checksummed; never the `-aarch64` tarball) if needed, then setup with `--lang=enUS`. Frozen CEF: Blizzard `HardwareAcceleration=false` plus `--in-process-gpu --disable-gpu-compositing --disable-direct-composition --disable-gpu-sandbox`. DXVK stays on so **WowClassic** gets Vulkan. Guest env includes `FEX_WIN_EXEC_QUERY_FALLBACK_MODE=2` (NX / NoExec bypass from [FEX #5328](https://github.com/FEX-Emu/FEX/issues/5328)).

**Battle.net on this Air is plug-and-play.** Login, Play, and the launch token all work. The client log shows `Launched .../WowClassic.exe` with `-launcherlogin -windowed -initialgamemode=bccfresh -uid wow_classic_anniversary`, cwd `_anniversary_`, PE32+ x86-64, then `Game is now running with game launch behavior set to exit`. `Client.GameLaunchWindowBehavior = "2"` exits the launcher on Play (by design). The guest script holds the VM past that exit and reaps CEF (`CrRendererMain` / `CrBrowserMain` / `CrUtilityMain`, leave `Agent.exe`) so WowClassic can allocate. That reap is the one memory action that actually freed RAM (Play 22:41: `MemAvailable` 0 → 296 MiB).

**WowClassic does not reach a window. That is FEX, not a missing `teonix-battlenet` flag.** Play 22:41: after CEF reap, top RSS was `Agent.exe` 172 / `WowClassic.exe` 155 MiB, then `RESULT: no-window`. Proton never logged `Game: WowClassic.exe`. No `_anniversary_/Logs/`, no `Errors/`. The process looped `err:seh:dispatch_exception assertion failure exception`. Same open Asahi/FEX bug as [FEX #5399](https://github.com/FEX-Emu/FEX/issues/5399) (Battle.net works; WoW starts and never creates a window). Related: [FEX #5328](https://github.com/FEX-Emu/FEX/issues/5328) (`_anniversary_` NoExec / C0000005). Play 22:59 with `FEX_WIN_EXEC_QUERY_FALLBACK_MODE=2` was the same stop: launcher `Launched`, then assertion, no HWND, no Proton `Game: WowClassic.exe`, no `_anniversary_/Logs`, no new `Data/` files. Do not keep turning Battle.net.config knobs.

**Resume when FEX moves (do not rebuild a patched FEX until the signal below).** This Air is `fex-emu-2604-1.fc44`. Upstream FEX is **2608** (2026-08-05); monthly tags, 2606 skipped. **2608 does not fix WoW.** chrisRidgers (Asahi, M1 Pro) retried Proton 11 + a newer kernel on 2026-08-12 in [#5399](https://github.com/FEX-Emu/FEX/issues/5399): still no window. 16 GiB Asahi would not fix #5399 — that reporter was already on an M1 Pro. Official WoW on this Mac is reboot to macOS and the Battle.net Mac client.

FrontMage got official Battle.net WoW running in July 2026 on **Android** (Lenovo Y700, Odin 2 Mini) with a custom FEX + Proton/Wine stack. He said the leftover work is FEX **and** Proton/wrapper/Turnip, “months.” Turtle WoW (1.12 private client) is a different binary — not proof Anniversary or Retail work.

PRs as of 2026-08-30:

- Merged, already in post-2604 git: [#5784](https://github.com/FEX-Emu/FEX/pull/5784) (prioritize fetch faults). Related earlier: [#5492](https://github.com/FEX-Emu/FEX/pull/5492), [#5535](https://github.com/FEX-Emu/FEX/pull/5535), [#5545](https://github.com/FEX-Emu/FEX/pull/5545).
- **Still open / load-bearing:** [#5785](https://github.com/FEX-Emu/FEX/pull/5785) — “one of the fixes required for #5399.” dragosol (2026-08-30): `#5785` on `main` (2608 + ~130 commits) got **Overwatch 2** (Steam, not Battle.net) past Eidolon; `#5781` / `#5783` / `#5784` alone were not enough; also needed [#5878](https://github.com/FEX-Emu/FEX/issues/5878) (thunk `r11` / stack protector). That run was QEMU+HVF Arch on an M3 Max with venus/MoltenVK — **not** Fedora Asahi muvm+Honeykrisp.

Do not re-try as “the fix”: x86 `WowClassic.exe` + FEX (this stack; `#5785` is the missing piece, NX fallback already tried); ARM64 `Wow.exe` + Wine ARM64 (DXVK can init, then black screen; Proton Experimental ARM64 also makes Battle.net pull the ARM64 client — never pick it). Fedora packaging here has lagged upstream by months. Try Asahi again only when **`#5785` is merged and chrisRidgers reports a window on Asahi** — not merely `dnf` showing 2605/2608. Then still expect 8 GiB + guest `SwapTotal=0` to need CEF reap and Cursor closed.

**This box is over the line even if FEX is fixed.** 8 GiB host, guest `MemTotal` 6166, `SwapTotal` 0, `max_map_count` 65530. The guest cannot `swapon` or raise `max_map_count`. Host swap is invisible inside the VM. Close Cursor/browser and keep the CEF-reap path. Fedora Asahi FEX here is `fex-emu-2604-1.fc44`. Do not shop Proton versions; never Proton Experimental ARM64.

**Why Play used to cancel itself.** `muvm --mem` is a ceiling, not a reservation — the guest takes pages on demand and returns them — so the old 2560 MiB clamp protected nothing and only guaranteed an in-guest OOM the moment Play spawned the game next to CEF. The ceiling is now ~85% of RAM (`--vram=2048`). `GameLaunchWindowBehavior=1` (minimize, Play 22:35) kept CEF at ~1.6 GiB with `MemAvailable=0` and OOM-killed the renderer (`RESULT: launcher-crash`). Do not switch back to 1.

**Do not write `WTF/Config.wtf` from scratch.** A generated file without `SET textLocale` makes WowClassic throw `assertion failure exception` on repeat and exit with no window, no `Logs/` and no `Errors/` — indistinguishable from a failed Play. The scripts merge windowed D3D11 1280×800 into WoW's own config and delete a config missing `textLocale` so the game rebuilds it.

**Play is the only way to start this game, and there is no scripted substitute.** Both candidates were measured, with the launcher up and the account signed in, and neither works — do not re-add them:

- `WowClassic.exe -windowed` throws `assertion failure exception` on repeat and never maps a window. The game will not start without the launch token Play hands it.
- `Battle.net.exe --exec="launch wow_classic_anniversary"` never incremented the launcher's own `Launched ...WoWClassic.exe` count.

So a failed Play is reported, not retried. `wownolauncher` just opens the launcher.

**Grep the client log case-insensitively.** Battle.net logs `Launched .../WoWClassic.exe` while the file on disk is `WowClassic.exe`. A case-sensitive match finds nothing, which had the Play verifier sitting out every real launch — no verdict, no notification.

Everything in this prefix reports the WM class `steam_app_battlenet` (Proton derives it from `SteamAppId`), so Hyprland rules and `StartupWMClass` match that class plus the window title — never `WowClassic.exe`. The 100×13 empty-title ghost HWND gets `no_focus` and no `min_size`. The Wine virtual desktop is scoped to `AppDefaults\Battle.net.exe` so the game gets a native window instead of rendering inside the launcher's.

Logs: `~/.local/state/teonix-battlenet.log`, with a greppable `RESULT: ok | no-window | launcher-crash` per Play. `TEONIX_BNET_DEBUG=1` adds Proton/DXVK logs under `~/.local/share/teonix/battlenet/logs/` — `WINEDEBUG=-all` is right for daily use and useless when a launch hangs silently. After `updatehome`, `teonix-battlenet` / the dock icon exec the working copy in `~/teonix/home/hosts/applenix/scripts/` when that file is executable — no `TEONIX_DEV` needed. Prefix: `~/.local/share/teonix/battlenet/`. Do not write `~/.fex-emu/Config.json`. Do not pick Proton Experimental (ARM64). Desktop entries (`teonix-battlenet`, `teonix-wow`) stay `Terminal=false` so a kitty tab is not mistaken for the client.

Guest detection must not use `pgrep -x muvm`: muvm renames itself to `libkrun VM` once the VM is up, so that check reports no guest while one is running. Match on `/proc/*/exe` instead — matching the command line makes any shell that merely mentions muvm look like a guest, which made a relaunch refuse itself.

If the kernel OOM-kills the guest:

```bash
sudo /usr/libexec/fedora-asahi-remix-scripts/setup-swap.sh --recreate 16G
```

### WowUp (`teonix-wowup`)

nixpkgs `wowup-cf` is an **x86_64 AppImage** — it cannot be a native aarch64 Home Manager package. Official **WowUp.CF 2.23.1** runs in the same **muvm + FEX** guest. **Quit Battle.net / WoW first** (`bnetkill`).

```bash
teonix-battlenet-kill
wowup
```

Add client folder (not a Windows `C:` path):

`~/.local/share/teonix/battlenet/prefix/pfx/drive_c/Program Files (x86)/World of Warcraft`

Then pick `_anniversary_` / `_classic_` / `_classic_era_` / `_retail_` as installed. Log: `~/.local/state/teonix-wowup.log`.
