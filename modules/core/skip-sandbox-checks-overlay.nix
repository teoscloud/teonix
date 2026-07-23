# Intentionally empty / unused.
#
# Previously this overlay set `doCheck = false` on openldap and fwupd so
# source builds would pass the sandbox. That *changes the derivation hash*,
# so cache.nixos.org never hits and Nix rebuilds fwupd/openldap *and* a huge
# chunk of the desktop stack (KDE/Plasma, etc.) locally — often hundreds of
# packages, one-by-one when max-jobs was 1.
#
# Binary cache paths already skip running those tests. Prefer substituting
# from https://cache.nixos.org. If a rare source build fails checks, fix it
# with a one-off `--option` / temporary overlay, not a permanent global one.

final: prev: { }
