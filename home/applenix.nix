{ config, pkgs, username, hostname, projectdir, ... }:

let
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
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.05";

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

  home.activation.clearBrowserStreamTargets = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    ${clearBrowserStreamTargets}
  '';

  imports = [
    ./hosts/applenix/modules/zshaliases.nix
    ./hosts/applenix/modules/dotfiles.nix
    ./hosts/applenix/modules/hyprflow.nix
  ];

  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "never";
  };

  home.activation.disableSwaync = config.lib.dag.entryAfter [ "writeBoundary" ] ''
    systemctl --user stop swaync.service 2>/dev/null || true
    systemctl --user mask swaync.service 2>/dev/null || true
  '';
}
