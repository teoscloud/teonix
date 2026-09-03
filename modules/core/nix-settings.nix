{ config, pkgs, stable-pkgs, lib, inputs, system ? "x86_64-linux", ... }:

{
  nix.settings = {
    download-buffer-size = 134217728;
    # Keep cache downloads moderate so they don't saturate disk/network during updates.
    max-substitution-jobs = 4;

    # x86_64 (24-thread / 32G nixbox): conservative desktop-friendly
    # parallelism, max-jobs × cores ≈ 6 threads worst-case for local compiles,
    # and the idle CPU/IO policy below still yields to interactive apps.
    #
    # aarch64 (applenix): the Asahi kernel and its Rust drivers are the big
    # local build and they are memory-hungry, so build one derivation at a time
    # but let it use every core. Two parallel kernel-sized jobs OOM an 8G Mac.
    max-jobs = if system == "x86_64-linux" then 2 else 1;
    cores = if system == "x86_64-linux" then 3 else 0;

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
    ]
    ++ lib.optionals (system == "x86_64-linux") [
      "https://chaotic-nyx.cachix.org"
      "https://nyx-cache.chaotic.cx/"
      "https://hyprland.cachix.org"
      "https://nix-gaming.cachix.org"
    ]
    ++ lib.optionals (system == "aarch64-linux") [
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
    ]
    ++ lib.optionals (system == "x86_64-linux") [
      "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
      "nyx-cache.chaotic.cx:dJxTrgMC3V3cFfyIiBQDQorG6k1LsqurH/srpMSq7qk="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      "nix-gaming.cachix.org-1:nbjlureqMbRAxR1gJ/f3hxemL9svXaZF/Ees8vCUUs4="
    ]
    ++ lib.optionals (system == "aarch64-linux") [
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  # When the session needs CPU/disk, nix-daemon yields (fixes desktop freezes during
  # systemupdate / local compiles). Applies to all nix-daemon builds, not just aliases.
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  nix.daemonIOSchedPriority = 7;

  # Soft cgroup caps so a big local rebuild can't OOM / fully pin the machine.
  # Absolute values only make sense on the 32G desktop; applenix may be an 8G
  # MacBook Air, where a 14G ceiling is no ceiling at all.
  #
  # aarch64 gets MemoryHigh only, deliberately no MemoryMax: the Asahi kernel
  # is a mandatory local build (no upstream cache), and a hard cap on a small
  # Mac turns "slow, swapping" into "SIGKILL near the end of the build".
  # MemoryHigh throttles and pushes pages to swap instead of killing.
  systemd.services.nix-daemon.serviceConfig = {
    CPUWeight = 10; # default 100 — prefer desktop/apps
    IOWeight = 10;
  }
  // (
    if system == "x86_64-linux" then
      {
        MemoryHigh = "10G"; # start reclaiming early
        MemoryMax = "14G"; # hard cap; keeps headroom for Hyprland/browsers
      }
    else
      {
        MemoryHigh = "80%";
      }
  );

  nixpkgs.config = {
    allowUnfree = true;
  };

  # Chaotic only — do NOT add overrideAttrs overlays here that change
  # derivation hashes (e.g. doCheck = false). Those bust cache.nixos.org
  # and force massive local rebuilds of dependents (KDE, fwupd tree, etc.).
  nixpkgs.overlays = lib.optionals (system == "x86_64-linux") [
    inputs.chaotic.overlays.default
  ];
}
