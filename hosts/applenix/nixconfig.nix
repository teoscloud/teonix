{ config, pkgs, lib, ... }:

{
  networking.hostName = "applenix";

  # Hyprland-only rice; skip full GNOME/Plasma session stacks on arm.
  services.desktopManager.gnome.enable = lib.mkForce false;
  services.desktopManager.plasma6.enable = lib.mkForce false;
  services.xserver.enable = lib.mkForce false;
  services.displayManager.defaultSession = lib.mkForce "hyprland";
}
