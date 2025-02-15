{ config, pkgs, hostname, ... }:

{
  # Generate a monitor configuration file for Hyprland.
  home.file.".config/hypr/monitor.conf".source = pkgs.writeText "monitor.conf" ''
    ${if hostname == "nixbox" then ''
      monitor = DP-1, 5120x1440@239.58, 0x0, 1, bitdepth, 8, vrr, 1
      monitor = HDMI-A-1, 1920x1080@60.00000, 1600x-1080, 1, bitdepth, 8
    '' else if hostname == "nixtop" then '' 
      monitor = eDP-1, 2880x1800@60, 0x0, 1.25, bitdepth, 8
    '' else ''
      monitor = , preferred, auto, 1
    ''}
  '';
}
