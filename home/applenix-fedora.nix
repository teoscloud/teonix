{
  lib,
  unstable-pkgs,
  stable-pkgs,
  ...
}:

{
  imports = [
    ./applenix.nix
    ./hosts/applenix/modules/fedora-session.nix
    ./hosts/applenix/modules/fedora-secrets.nix
    ./hosts/applenix/modules/fedora-zshaliases.nix
  ];

  home.packages = import ../modules/apps/package-set.nix {
    inherit unstable-pkgs stable-pkgs lib;
  };
}
