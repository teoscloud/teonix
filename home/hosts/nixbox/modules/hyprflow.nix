{ unstable-pkgs, ... }:

let
  hyprflow = import ../../../../modules/apps/hyprflow.nix {
    lib = unstable-pkgs.lib;
    rustPlatform = unstable-pkgs.rustPlatform;
    fetchFromGitHub = unstable-pkgs.fetchFromGitHub;
  };
in
{
  # Declarative autosave timer (replaces `hyprflow autosave --install`).
  # HM uses Unit/Service/Timer/Install — not unitConfig/serviceConfig (those become invalid sections).
  systemd.user.services.hyprflow-autosave = {
    Unit = {
      Description = "Hyprflow autosave Hyprland session";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      # Keep `latest` in sync so plain restore works; autosave-* alone is not the default session.
      ExecStart = "${hyprflow}/bin/hyprflow autosave --now && ${hyprflow}/bin/hyprflow save --force";
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
      ExecStart = "${hyprflow}/bin/hyprflow save --force";
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
