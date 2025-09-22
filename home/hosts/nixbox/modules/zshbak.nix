{ config, pkgs, username, hostname, projectdir, ... }:

{

  # Generate a monitor configuration file for Hyprland.
  home.file.".zshaliases.sh".source = pkgs.writeText ".zshaliases.sh" ''
  alias systemupdate='cd ${projectdir} && export NIXPKGS_ALLOW_INSECURE=1 && nix flake update && sudo -E NIXPKGS_ALLOW_INSECURE=1 nixos-rebuild switch --flake "path:."#${hostname} --impure && home-manager switch --flake "path:."#${hostname}'
  alias updatehome='cd ${projectdir} && home-manager switch --flake "path:."#${hostname}'
  alias nixupgrade='cd ${projectdir} && sudo -E NIXPKGS_ALLOW_INSECURE=1 nixos-rebuild switch --flake "path:."#${hostname} --impure'
  alias nixupdate='cd ${projectdir} && nix flake update'

  debugupdate() {
    set -euo pipefail
    cd ${projectdir}

    LOG="$(mktemp)"
    cleanup() { rm -f "$LOG"; }
    trap cleanup EXIT

    # run rebuild without flake update; capture only stderr to LOG
    if sudo nixos-rebuild switch \
          --flake "path:."#${hostname} \
          --impure \
          --show-trace \
          -L \
          --verbose \
          --option eval-cache false \
          2> "$LOG"
    then
      # success path -> also do HM (with traces), then exit 0
      home-manager switch --flake "path:."#${hostname} -v --show-trace
      return 0
    fi

    # failure path
    echo
    echo "❌ nixos-rebuild failed — attempting to locate the culprit package…"
    # show the last ~80 lines of the error so you see context
    tail -n 80 "$LOG" >&2 || true

    # Extract the “Package ‘…’” name if present
    PKG_NAME="$(grep -oE "Package ‘[^’]+’" "$LOG" | sed "s/^Package ‘//;s/’$//" | tail -n1 || true)"
    [ -n "''${PKG_NAME:-}" ] && echo "Found problematic package: $PKG_NAME"

    # Build system toplevel path with insecure allowed JUST for analysis
    SYS="$(NIXPKGS_ALLOW_INSECURE=1 nix build .#nixosConfigurations.${hostname}.config.system.build.toplevel \
            --impure --no-link --print-out-paths 2>/dev/null | tail -n1 || true)"

    if [ -z "''${SYS:-}" ]; then
      echo "Could not compute system path; see log: $LOG"
      return 1
    fi

    # Find any qtwebengine-like store path in the closure (works even if attr name differs)
    CULPRIT_PATH="$(nix path-info -r "$SYS" | grep -Ei '/qt(web)?engine' | head -n1 || true)"

    if [ -n "''${CULPRIT_PATH:-}" ]; then
      echo
      echo "🔎 Why your system depends on ''${PKG_NAME:-qtwebengine}:"
      # don’t fail the whole function if these commands return non-zero
      set +e
      nix why-depends "$SYS" "$CULPRIT_PATH"
      echo
      echo "Direct referrers of that store path:"
      nix-store --query --referrers "$CULPRIT_PATH"
      set -e
    else
      echo "Couldn’t find a qtwebengine path in the system closure. Check: $LOG"
    fi

    return 1
  }

  alias debugupdate=debugupdate
'';
  
}
