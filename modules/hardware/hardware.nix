{ config, lib, system ? "x86_64-linux", ... }:

{
  imports = [ ./hardware-base.nix ]
    ++ lib.optionals (system == "x86_64-linux") [ ./hardware-x86.nix ];
}
