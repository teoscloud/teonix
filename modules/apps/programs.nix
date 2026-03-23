{ config, pkgs, ... }:

{
  # for cachy
  #chaotic.mesa-git.enable = true;

  programs = {
    xwayland.enable = true;
    hyprlock.enable = true;

    # Hyprland + xdg-desktop-portal-hyprland from nixos-unstable (matches wlroots/aquamarine in tree).
    # Do not override with Hyprland git main unless you pin a known-good rev.
    hyprland = {
      enable = true;
      xwayland.enable = true;
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


