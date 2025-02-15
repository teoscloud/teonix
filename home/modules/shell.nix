{ config, pkgs, username, hostname, projectdir, ... }:

{

  # Generate a monitor configuration file for Hyprland.
  home.file.".zshaliases.sh".source = pkgs.writeText ".zshaliases.sh" ''
    alias systemupdate='cd ${projectdir} && nix flake update && sudo nixos-rebuild switch --flake "path:."#${hostname} --impure && home-manager switch --flake "path:."#${hostname}'
    alias updatehome='cd ${projectdir} && home-manager switch --flake "path:."#${hostname}'
    alias nixupgrade='cd ${projectdir} && sudo nixos-rebuild switch --flake "path:."#${hostname} --impure'
    alias nixupdate='cd ${projectdir} && nix flake update'
  '';
  
}
