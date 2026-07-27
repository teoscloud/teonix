{ config, pkgs, stable-pkgs, lib, ... }:

{
  # Build parallelism / desktop-friendly caps live in modules/core/nix-settings.nix
  # (max-jobs=2, cores=3, idle CPU/IO, memory caps). Do not set max-jobs=auto /
  # cores=0 here — that saturates every core during systemupdate.
}
