{ config, pkgs, inputs, ... }:

{
  # for cachy
  #chaotic.mesa-git.enable = true;

  programs = {
    xwayland.enable = true;
    hyprlock.enable = true;

    # desktop
    hyprland = {
      enable = true;
      xwayland.enable = true;

      # set the flake package
      package = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      # make sure to also set the portal package, so that they are in sync
      portalPackage = inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;

    };

    # gaming
    steam = {
      enable = true;
      remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
      dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
      localNetworkGameTransfers.openFirewall = true; # Open ports in the firewall for Steam Local Network Game Transfers

      gamescopeSession.enable = true;
    };
    gamemode.enable = true;

  };
}


