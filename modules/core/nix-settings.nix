{ config, pkgs, stable-pkgs, lib, inputs, ... }:

{
  nix.settings = {
    download-buffer-size = 134217728;
    # Parallel downloads from caches (default is low)
    max-substitution-jobs = 32;

    experimental-features = [
      "nix-command"
      "flakes"
    ];

    # cache.nixos.org FIRST — most packages hit here.
    # Chaotic/Hyprland/gaming caches only for their specialized builds.
    # NOTE: listing substituters replaces the NixOS default list, so
    # cache.nixos.org must be included explicitly.
    substituters = [
      "https://cache.nixos.org"
      "https://chaotic-nyx.cachix.org"
      "https://nyx-cache.chaotic.cx/"
      "https://hyprland.cachix.org"
      "https://nix-gaming.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ];
  };

  nixpkgs.config = {
    allowUnfree = true;
  };

  # Chaotic only — do NOT add overrideAttrs overlays here that change
  # derivation hashes (e.g. doCheck = false). Those bust cache.nixos.org
  # and force massive local rebuilds of dependents (KDE, fwupd tree, etc.).
  nixpkgs.overlays = [
    inputs.chaotic.overlays.default
  ];
}
