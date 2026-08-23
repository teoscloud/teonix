{ config, lib, system ? "x86_64-linux", ... }:

{
  imports = [ ./kernel-base.nix ]
    ++ lib.optionals (system == "x86_64-linux") [ ./kernel-x86.nix ];
}
