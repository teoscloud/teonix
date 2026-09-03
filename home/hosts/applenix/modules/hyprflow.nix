{ pkgs, ... }:

let
  # This module is shared by #applenix (NixOS) and #applenix-fedora, where
  # hyprflow is a Home Manager package instead of a system one — so the unit
  # cannot hardcode /run/current-system. It also runs on a timer, which would
  # otherwise leave a permanently failed unit whenever the session is not
  # Hyprland (e.g. logged into Plasma on Fedora).
  hf = pkgs.writeShellScript "hyprflow-session-unit" ''
    set -u

    live=0
    for s in "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"/hypr/*/.socket.sock; do
      [ -S "$s" ] && live=1 && break
    done
    if [ "$live" -eq 0 ]; then
      echo "no running Hyprland instance — nothing to save"
      exit 0
    fi

    for c in \
      "$HOME/.nix-profile/bin/hyprflow" \
      "/etc/profiles/per-user/''${USER:-}/bin/hyprflow" \
      /run/current-system/sw/bin/hyprflow
    do
      [ -x "$c" ] && exec "$c" "$@"
    done

    echo "hyprflow is in neither the Home Manager nor the system profile" >&2
    exit 1
  '';
in
{
  systemd.user.services.hyprflow-autosave = {
    Unit = {
      Description = "Hyprflow autosave Hyprland session";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${hf} autosave --now";
      ExecStartPost = "${hf} save --force";
    };
  };

  systemd.user.services.hyprflow-save-on-exit = {
    Unit = {
      Description = "Save Hyprland session before logout or shutdown";
      DefaultDependencies = false;
      Before = [
        "shutdown.target"
        "exit.target"
        "reboot.target"
        "halt.target"
      ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${hf} save --force";
      TimeoutStartSec = 30;
    };
    Install = {
      WantedBy = [ "exit.target" "shutdown.target" ];
    };
  };

  systemd.user.timers.hyprflow-autosave = {
    Unit = {
      Description = "Hyprflow periodic session autosave";
    };
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "3min";
    };
    Install = {
      WantedBy = [ "timers.target" ];
    };
  };
}
