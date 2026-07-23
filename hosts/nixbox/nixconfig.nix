{ config, pkgs, stable-pkgs, lib, ... }:

{
  nix.settings = {
    # Parallel derivations (was 1 — that serialized every compile).
    # "auto" ≈ one job per CPU; pair with cores for within-job parallelism.
    max-jobs = "auto";
    cores = 0; # 0 = use all available cores per job
  };
}
