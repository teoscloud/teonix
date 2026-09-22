{ config, pkgs, lib, system ? "x86_64-linux", ... }:

{
  programs = {
    xwayland.enable = true;
    hyprlock.enable = true;

    hyprland = {
      enable = true;
      xwayland.enable = true;
      # Adds the "Hyprland (UWSM)" session next to plain "Hyprland": the
      # compositor runs as wayland-wm@hyprland.desktop.service and `uwsm app --` puts
      # every launched app in its own scope under app-graphical.slice. Mainframe's
      # compositor-core.nix pins and fences by those unit names; elsewhere it is
      # just a cleaner systemd session. UWSM owns graphical-session.target, so the
      # hand-rolled dbus/import-environment lines in hyprland.conf are gone.
      withUWSM = true;
    };

    steam = lib.mkIf (system == "x86_64-linux") {
      enable = true;
      remotePlay.openFirewall = true;
      dedicatedServer.openFirewall = true;
      localNetworkGameTransfers.openFirewall = true;
      gamescopeSession.enable = true;
    };

    gamemode.enable = lib.mkIf (system == "x86_64-linux") true;
  };
}
