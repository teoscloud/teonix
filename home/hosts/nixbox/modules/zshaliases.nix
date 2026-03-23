{ config, pkgs, username, hostname, projectdir, ... }:

{

  # Generate a monitor configuration file for Hyprland.
  home.file.".zshaliases.sh".source = pkgs.writeText ".zshaliases.sh" ''
    alias systemupdate='cd ${projectdir} && nix flake update && sudo nixos-rebuild switch --flake "path:."#${hostname} --impure && home-manager switch --flake "path:."#${hostname}'
    alias updatehome='cd ${projectdir} && home-manager switch --flake "path:."#${hostname}'
    alias nixupgrade='cd ${projectdir} && sudo nixos-rebuild switch --flake "path:."#${hostname} --impure'
    alias nixupdate='cd ${projectdir} && nix flake update'
    # Keep last 10 system + home-manager generations, then GC (frees store space)
    alias nixclean='sudo nix-env -p /nix/var/nix/profiles/system --delete-generations +10 && nix-env -p /nix/var/nix/profiles/per-user/${username}/home-manager --delete-generations +10 2>/dev/null; nix-env -p /nix/var/nix/profiles/per-user/${username}/profile --delete-generations +10 2>/dev/null; sudo nix-store --gc'
  '';
  
}
