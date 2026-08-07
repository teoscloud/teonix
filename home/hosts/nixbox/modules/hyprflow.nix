{ ... }:

# Use the system package (`modules/apps/packages.nix`) — do not rebuild hyprflow here.
let
  hf = "/run/current-system/sw/bin/hyprflow";
in
{
  # Declarative autosave timer (replaces `hyprflow autosave --install`).
  # IMPORTANT: systemd ExecStart cannot use shell `&&` — use ExecStart + ExecStartPost.
  systemd.user.services.hyprflow-autosave = {
    Unit = {
      Description = "Hyprflow autosave Hyprland session";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      # Rotate autosave-* then refresh `latest` (plain `hyprflow restore` default).
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
