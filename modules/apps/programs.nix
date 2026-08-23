{ config, pkgs, lib, system ? "x86_64-linux", ... }:

{
  programs = {
    xwayland.enable = true;
    hyprlock.enable = true;

    hyprland = {
      enable = true;
      xwayland.enable = true;
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
