# Packages whose test suites assume a full Linux host (e.g. /proc/cmdline, timing) and
# fail in the Nix build sandbox when built from source. Skipping checks matches what you
# get from cache.nixos.org (pre-built binaries) without running tests locally.

final: prev: {
  openldap = prev.openldap.overrideAttrs (old: {
    doCheck = false;
  });

  # fwupd tests hit /proc/cmdline; sandbox returns EPERM and Meson tests abort.
  fwupd = prev.fwupd.overrideAttrs (old: {
    doCheck = false;
  });
}
