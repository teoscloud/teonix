{ config, pkgs, stable-pkgs, lib, ... }:

{
  nix.settings = {

    download-buffer-size = 134217728;

    experimental-features = [
      "nix-command"
      "flakes"
    ];

    #hyprland cachix
    substituters = [ 
      "https://hyprland.cachix.org" 
      "https://nix-gaming.cachix.org" 
    ];
    trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" 
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4=" 
    ];

  };

  # Allow unfree packages globally for both stable and unstable package sets
  nixpkgs.config = {
    allowUnfree = true;

    # Optional: Allow specific unfree packages, e.g., unrar
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      
    ];
  };
}
