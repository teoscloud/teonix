{ pkgs, lib, username, projectdir, ... }:

let
  shDate = "$(date -Iseconds)";
  flakeAttr = "applenix-fedora";
  aliases = pkgs.writeText "teonix-fedora-aliases.sh" ''
    # Fedora + Nix Home Manager. Same names as nixbox; none of them call nixos-rebuild.
    #
    #   updatehome / rebuild / nixupgrade  apply #${flakeAttr} (path:. so local edits count)
    #   nixupdate                          flake.lock only
    #   systemupdate                       flake update + apply
    #   hm-gens / hm-rollback / nixclean
    #
    _say() { printf '%s\n' "$*"; }
    _nix_nice() { nice -n 19 ionice -c3 "$@"; }
    _nix_rebuild_opts=(--option max-jobs 1 --option cores 0)

    _nix_ready() {
      if ! command -v nix >/dev/null 2>&1; then
        # shellcheck source=/dev/null
        [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ] \
          && . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
      fi
      export PATH="''${PATH}:/nix/var/nix/profiles/default/bin''${HOME:+:$HOME/.nix-profile/bin}"
      command -v nix >/dev/null 2>&1 || {
        _say "nix is not on PATH — open a new login shell or:"
        _say "  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
        return 1
      }
    }

    _hm() {
      _nix_ready || return
      cd "${projectdir}" || return
      if command -v home-manager >/dev/null 2>&1; then
        _nix_nice home-manager "$@"
      else
        _nix_nice nix run --accept-flake-config nixpkgs#home-manager -- "$@"
      fi
    }

    updatehome() {
      _hm switch -b bak --flake "path:.#${flakeAttr}" "''${_nix_rebuild_opts[@]}" "$@"
    }
    rebuild() { updatehome "$@"; }
    nixupgrade() { updatehome "$@"; }
    systemupdate() {
      _nix_ready || return
      cd "${projectdir}" || return
      _nix_nice nix flake update && updatehome "$@"
    }
    nixupdate() {
      _nix_ready || return
      cd "${projectdir}" || return
      _nix_nice nix flake update
    }

    alias nixclean='_nix_ready && nix-env -p /nix/var/nix/profiles/per-user/${username}/home-manager --delete-generations +10 2>/dev/null; nix-env -p /nix/var/nix/profiles/per-user/${username}/profile --delete-generations +10 2>/dev/null; nix store gc'

    nix-gens() { _say "No NixOS system profile on Fedora — use hm-gens"; }
    nix-rollback() { _say "No NixOS system profile on Fedora — use hm-rollback"; }
    hm-gens() { _nix_ready && home-manager generations 2>/dev/null | head -25; }
    hm-rollback() { _hm switch --rollback; }

    _nix_stable_state() { _say "''${HOME}/.config/teonix/active-stable-${flakeAttr}"; }
    _nix_stable_index() {
      mkdir -p "''${HOME}/.config/teonix"
      local f i=1
      f="$(_nix_stable_state)"
      [[ -f $f ]] && read -r i < "$f" || i=1
      case $i in 1|2|3|4) _say "$i" ;; *) _say 1 ;; esac
    }
    _nix_stable_copy_lock() {
      cd "${projectdir}" || return 1
      local i src
      i="$(_nix_stable_index)"
      src="flake.lock.stable.$i"
      if [[ ! -f $src ]]; then _say "No $src — run nixstablesave first (active slot $i)."; return 1; fi
      cp "$src" flake.lock
      _say "flake.lock <- $src (active slot $i)"
    }

    nixstableset() {
      local n
      n=$1
      if [[ "$n" != 1 && "$n" != 2 && "$n" != 3 && "$n" != 4 ]]; then _say "usage: nixstableset 1..4"; return 1; fi
      mkdir -p "''${HOME}/.config/teonix"
      _say "$n" > "''${HOME}/.config/teonix/active-stable-${flakeAttr}"
      _say "Active stable slot: $n (stablesystemupdate / stablenixupdate use flake.lock.stable.$n)"
    }
    alias nixstableuse1='nixstableset 1'
    alias nixstableuse2='nixstableset 2'
    alias nixstableuse3='nixstableset 3'
    alias nixstableuse4='nixstableset 4'

    nix-stable-save() {
      cd "${projectdir}" || return 1
      if [[ -f flake.lock.stable && ! -f flake.lock.stable.1 ]]; then mv -f flake.lock.stable flake.lock.stable.1; _say "(migrated flake.lock.stable -> flake.lock.stable.1)"; fi
      local s t
      for s in 3 2 1; do
        t=$((s + 1))
        [[ -f flake.lock.stable.$s ]] && mv -f "flake.lock.stable.$s" "flake.lock.stable.$t"
      done
      cp flake.lock flake.lock.stable.1
      mkdir -p "''${HOME}/.config/teonix"
      _say 1 > ''${HOME}/.config/teonix/active-stable-${flakeAttr}
      _say "${shDate} fedora-hm host ${flakeAttr} -> flake.lock.stable.1" >> .nix-stable-log.txt
      _say "Saved current flake.lock as stable.1 (shifted 1->2 .. 3->4; dropped old slot 4). Active stable -> 1. Log: .nix-stable-log.txt"
    }
    alias nixstablesave='nix-stable-save'

    stablenixupdate() { _nix_stable_copy_lock; }
    stablenixupgrade() { _nix_stable_copy_lock && updatehome "$@"; }
    stableupdatehome() { _nix_stable_copy_lock && updatehome "$@"; }
    stablesystemupdate() { _nix_stable_copy_lock && updatehome "$@"; }
    nix-stable-switch() { stablesystemupdate "$@"; }
    nix-stable-restore-lock() { stablenixupdate; }
    nix-stable-diff() {
      cd "${projectdir}" || return 1
      local i
      i="$(_nix_stable_index)"
      [[ -f flake.lock.stable.$i ]] || { _say "No flake.lock.stable.$i"; return 1; }
      diff -u "flake.lock.stable.$i" flake.lock | less
    }
    nix-stable-status() {
      cd "${projectdir}" || return 1
      local i s
      i="$(_nix_stable_index)"
      _say "Active stable slot: $i  (state: ''${HOME}/.config/teonix/active-stable-${flakeAttr})"
      for s in 1 2 3 4; do
        if [[ -f flake.lock.stable.$s ]]; then
          _say "  slot $s: present"
        else
          _say "  slot $s: (empty)"
        fi
      done
      if [[ -f flake.lock.stable.$i ]]; then
        if diff -q "flake.lock.stable.$i" flake.lock >/dev/null 2>&1; then _say "flake.lock matches active stable"; else _say "flake.lock differs from active stable"; fi
      fi
    }

    alias hfsave='hyprflow save'
    alias hfrestore='hyprflow restore'
    alias hflist='hyprflow list'
    alias hfstatus='systemctl --user status hyprflow-autosave.timer'

    # Quickshell rice switch (mainframe is the HM default; glass is optional)
    # Host muvm + FEX Steam. Never Nixpkgs Steam.
    alias steam='teonix-steam'
    alias steamkill='teonix-steam-kill'
    alias battlenet='teonix-battlenet'
    alias bnet='teonix-battlenet'
    alias bnetkill='teonix-battlenet-kill'
    alias wowup='teonix-wowup'

    alias qsmainframe='bash "$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe/scripts/qsmainframe.sh"'
    alias qsglass='bash "$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe/scripts/qsglass.sh"'
    alias qstheme='bash "$HOME/teonix/home/hosts/nixbox/dotfiles/config/quickshell-mainframe/scripts/qs-live-ipc.sh" theme toggle'

    alias mvpn='mullvad status'
    alias mvpnon='mullvad connect'
    alias mvpnoff='mullvad disconnect'
    alias mvpnse='mullvad relay set location se sto && mullvad connect'
    alias mvpnus='mullvad relay set location us && mullvad connect'
    alias mvpngui='mullvad-vpn'
  '';
in
{
  # Replaces the NixOS aliases imported via home/applenix.nix.
  home.file.".zshaliases.sh" = lib.mkForce { source = aliases; };

  # Fedora login shells are often bash (TTY / Konsole before chsh).
  home.file.".bashrc.d/teonix-aliases.sh".source = aliases;
  home.file.".bash_aliases".source = aliases;
}
