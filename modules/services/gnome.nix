# GNOME desktop apps and optional services
# GNOME session is enabled in system-services.nix (desktopManager.gnome); SDDM lists it.
{ config, pkgs, lib, ... }:

{
  # Resolve conflict: Plasma uses ksshaskpass, GNOME/seahorse uses seahorse ssh-askpass.
  # Prefer Seahorse; works for SSH prompts in both Plasma and GNOME sessions.
  programs.ssh.askPassword = lib.mkForce "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";

  # Optional: disable GNOME games (core desktop is from desktopManager.gnome)
  services.gnome.games.enable = false;

  # Common GNOME apps (install alongside Plasma) - use top-level attr names
  environment.systemPackages = with pkgs; [
    nautilus
    gnome-terminal
    gnome-system-monitor
    gnome-calculator
    gnome-disk-utility
    file-roller
    evince
    gnome-tweaks
    gnome-control-center
    simple-scan
    cheese
    gnome-screenshot
    gnome-font-viewer
    gnome-clocks
    gnome-weather
  ];
}
