{ config, pkgs, username, homeDirectory ? "/home/${username}", hostname, projectdir, ... }:

let
  # Chromium/Brave refuse to open a Pulse stream when the session default sink
  # is at extreme rates (e.g. 384 kHz) → NullAudioSink, no playback session.
  # Pin browsers to Scarlett Line1 (48 kHz) regardless of whatever owns "default".
  scarlettLine1 = "alsa_output.usb-Focusrite_Scarlett_2i4_USB-00.HiFi__Line1__sink";
  wrapBrowserPulse = name: pkg:
    pkgs.symlinkJoin {
      inherit name;
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for b in brave brave-browser google-chrome-stable google-chrome chromium chromium-browser; do
          if [ -e "$out/bin/$b" ]; then
            wrapProgram "$out/bin/$b" --set PULSE_SINK "${scarlettLine1}"
          fi
        done
      '';
    };

  clearBrowserStreamTargets = pkgs.writeShellScript "clear-browser-stream-targets" ''
    set -euo pipefail
    sp="$HOME/.local/state/wireplumber/stream-properties"
    [ -f "$sp" ] || exit 0
    ${pkgs.python3}/bin/python3 - "$sp" <<'PY'
    import re, sys
    from pathlib import Path
    path = Path(sys.argv[1])
    text = path.read_text(encoding="utf-8", errors="replace")
    browser = ("Brave", "Chromium", "Google\\sChrome", "firefox", "Chrome")
    out, changed = [], False
    for line in text.splitlines(True):
        if line.startswith("Output/Audio:application.name:") and any(b in line for b in browser):
            new = re.sub(r',\s*"target"\s*:\s*"[^"]*"', "", line)
            new = re.sub(r'"target"\s*:\s*"[^"]*"\s*,\s*', "", new)
            changed = changed or new != line
            out.append(new)
        else:
            out.append(line)
    if changed:
        path.write_text("".join(out), encoding="utf-8")
        print(f"cleared browser stream targets in {path}")
    PY
  '';
in
{
  home.username = username;
  home.homeDirectory = homeDirectory;
  home.stateVersion = "25.05";

  # BusChain Control → Quickshell mixer / HW scroll strip
  home.sessionVariables = {
    BUSCHAIN_CONTROL_QS_MIXER = "1";
    BUSCHAIN_CONTROL_QS_STRIP = "1";
  };

  # Shadow system brave/chrome so dock/gtk-launch pick the Pulse-pinned wrappers.
  home.packages = [
    (wrapBrowserPulse "brave-scarlett-pulse" pkgs.brave)
    (wrapBrowserPulse "google-chrome-scarlett-pulse" pkgs.google-chrome)
    (wrapBrowserPulse "chromium-scarlett-pulse" pkgs.chromium)
  ];

  # In your home.nix or equivalent
  home.file.".config/docker/daemon.json".text = ''
    {
      "data-root": "/home/teodor/mnt/qvo870/dockerdata"
    }
  '';

  # Mirror system WirePlumber browser rules so updatehome applies without waiting
  # for nixos-rebuild (same fix as services.pipewire.wireplumber.extraConfig).
  home.file.".config/wireplumber/wireplumber.conf.d/99-browsers-no-stale-target.conf".text = ''
    stream.rules = [
      {
        matches = [ { application.name = "Brave" } ]
        actions = { update-props = { state.restore-target = false } }
      }
      {
        matches = [ { application.name = "Chromium" } ]
        actions = { update-props = { state.restore-target = false } }
      }
      {
        matches = [ { application.name = "Google Chrome" } ]
        actions = { update-props = { state.restore-target = false } }
      }
      {
        matches = [ { application.name = "firefox" } ]
        actions = { update-props = { state.restore-target = false } }
      }
      {
        matches = [ { application.process.binary = "brave" } ]
        actions = { update-props = { state.restore-target = false } }
      }
      {
        matches = [ { application.process.binary = "chrome" } ]
        actions = { update-props = { state.restore-target = false } }
      }
      {
        matches = [ { application.process.binary = "chromium" } ]
        actions = { update-props = { state.restore-target = false } }
      }
      {
        matches = [ { application.process.binary = "firefox" } ]
        actions = { update-props = { state.restore-target = false } }
      }
      {
        matches = [ { application.process.binary = "zen" } ]
        actions = { update-props = { state.restore-target = false } }
      }
    ]
  '';

  # Strip sticky browser stream targets WirePlumber already saved.
  home.activation.clearBrowserStreamTargets = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${clearBrowserStreamTargets}
  '';

  # ✅ Import modules from `home/hosts/nixbox/modules`
  imports = [
    ./hosts/nixbox/modules/zshaliases.nix  # ✅ Renamed from shell.nix
    ./hosts/nixbox/modules/dotfiles.nix
    ./hosts/nixbox/modules/hyprflow.nix
  ];

  services.udiskie = {
    enable = true;
    automount = true;  # Automatically mount new devices
    notify = true;     # Show notifications
    tray = "never";    # Disabled: tray icon hover triggered Hyprland CPopup::onCommit crash
  };

  # Quickshell owns org.freedesktop.Notifications — mask swaync's user unit
  # (swaynotificationcenter ships WantedBy=graphical-session.target)
  home.activation.disableSwaync = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    systemctl --user stop swaync.service 2>/dev/null || true
    systemctl --user mask swaync.service 2>/dev/null || true
  '';
}
