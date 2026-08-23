{ ... }:

let
  hf = "/run/current-system/sw/bin/hyprflow";
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
