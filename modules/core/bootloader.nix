{ config, lib, system ? "x86_64-linux", ... }:

{
  imports = [ ./bootloader-base.nix ]
    ++ lib.optionals (system == "x86_64-linux") [ ./bootloader-x86.nix ];
}
