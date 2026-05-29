{ config, pkgs, stable-pkgs, lib, inputs, ... }:

{
  nix.settings = {

    download-buffer-size = 134217728;

    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # Binary caches for faster package downloads
    substituters = [ 
      "https://hyprland.cachix.org" 
      "https://nix-gaming.cachix.org"
      "https://chaotic-nyx.cachix.org"  # Chaotic packages (including CachyOS kernel binaries)
    ];
    trusted-public-keys = [
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc=" 
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="  # Chaotic cache key
    ];

  };

  # Allow unfree packages globally for both stable and unstable package sets
  nixpkgs.config = {
    allowUnfree = true;

    # Optional: Allow specific unfree packages, e.g., unrar
    allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
      
    ];
  };

  # Add chaotic overlay to system pkgs so kernel packages can access it
  nixpkgs.overlays = [
    inputs.chaotic.overlays.default
    (import ./skip-sandbox-checks-overlay.nix)
  ];
}
