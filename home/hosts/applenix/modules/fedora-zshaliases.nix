{ pkgs, lib, username, projectdir, ... }:

let
  shDate = "$(date -Iseconds)";
  flakeAttr = "applenix-fedora";
in
{
  # Replaces the NixOS aliases imported via home/applenix.nix.
  home.file.".zshaliases.sh" = lib.mkForce {
    source = pkgs.writeText ".zshaliases.sh" ''
      _nix_nice() { nice -n 19 ionice -c3 "$@"; }
      _nix_rebuild_opts=(--option max-jobs 1 --option cores 0)

      alias updatehome='cd ${projectdir} && _nix_nice home-manager switch -b bak --flake "path:."#${flakeAttr}'
      alias systemupdate='cd ${projectdir} && _nix_nice nix flake update && _nix_nice home-manager switch -b bak --flake "path:."#${flakeAttr}'
      alias nixupgrade='cd ${projectdir} && _nix_nice home-manager switch -b bak --flake "path:."#${flakeAttr}'
      alias nixupdate='cd ${projectdir} && _nix_nice nix flake update'
      alias nixclean='nix-env -p /nix/var/nix/profiles/per-user/${username}/home-manager --delete-generations +10 2>/dev/null; nix-env -p /nix/var/nix/profiles/per-user/${username}/profile --delete-generations +10 2>/dev/null; nix-store --gc'

      alias nix-gens='echo "No NixOS system profile on Fedora — use hm-gens"'
      alias nix-rollback='echo "No NixOS system profile on Fedora — use hm-rollback"'
      alias hm-gens='home-manager generations 2>/dev/null | head -25'
      alias hm-rollback='home-manager switch --rollback'

      _nix_stable_state() { print -r -- "''${HOME}/.config/teonix/active-stable-${flakeAttr}" }
      _nix_stable_index() {
        mkdir -p "''${HOME}/.config/teonix"
        local f i=1
        f="$(_nix_stable_state)"
        [[ -f $f ]] && read -r i < "$f" || i=1
        case $i in 1|2|3|4) print -r -- "$i" ;; *) print -r -- 1 ;; esac
      }
      _nix_stable_copy_lock() {
        cd "${projectdir}" || return 1
        local i src
        i="$(_nix_stable_index)"
        src="flake.lock.stable.$i"
        if [[ ! -f $src ]]; then print -r -- "No $src — run nixstablesave first (active slot $i)."; return 1; fi
        cp "$src" flake.lock
        print -r -- "flake.lock <- $src (active slot $i)"
      }

      nixstableset() {
        local n
        n=$1
        if [[ "$n" != 1 && "$n" != 2 && "$n" != 3 && "$n" != 4 ]]; then print -r -- "usage: nixstableset 1..4"; return 1; fi
        mkdir -p "''${HOME}/.config/teonix"
        print -r -- "$n" > "''${HOME}/.config/teonix/active-stable-${flakeAttr}"
        print -r -- "Active stable slot: $n (stablesystemupdate / stablenixupdate use flake.lock.stable.$n)"
      }
      alias nixstableuse1='nixstableset 1'
      alias nixstableuse2='nixstableset 2'
      alias nixstableuse3='nixstableset 3'
      alias nixstableuse4='nixstableset 4'

      nix-stable-save() {
        cd "${projectdir}" || return 1
        if [[ -f flake.lock.stable && ! -f flake.lock.stable.1 ]]; then mv -f flake.lock.stable flake.lock.stable.1; print -r -- "(migrated flake.lock.stable -> flake.lock.stable.1)"; fi
        local s t
        for s in 3 2 1; do
          t=$((s + 1))
          [[ -f flake.lock.stable.$s ]] && mv -f "flake.lock.stable.$s" "flake.lock.stable.$t"
        done
        cp flake.lock flake.lock.stable.1
        mkdir -p "''${HOME}/.config/teonix"
        print -r -- 1 > ''${HOME}/.config/teonix/active-stable-${flakeAttr}
        print -r -- "${shDate} fedora-hm host ${flakeAttr} -> flake.lock.stable.1" >> .nix-stable-log.txt
        print -r -- "Saved current flake.lock as stable.1 (shifted 1->2 .. 3->4; dropped old slot 4). Active stable -> 1. Log: .nix-stable-log.txt"
      }
      alias nixstablesave='nix-stable-save'

      stablenixupdate() { _nix_stable_copy_lock; }
      stablenixupgrade() {
        _nix_stable_copy_lock || return
        cd "${projectdir}" && _nix_nice home-manager switch -b bak --flake "path:."#${flakeAttr}
      }
      stableupdatehome() {
        _nix_stable_copy_lock || return
        cd "${projectdir}" && _nix_nice home-manager switch -b bak --flake "path:."#${flakeAttr}
      }
      stablesystemupdate() {
        _nix_stable_copy_lock || return
        cd "${projectdir}" && _nix_nice home-manager switch -b bak --flake "path:."#${flakeAttr}
      }
      nix-stable-switch() { stablesystemupdate "$@"; }

      nix-stable-restore-lock() { stablenixupdate; }
      nix-stable-diff() {
        cd "${projectdir}" || return 1
        local i
        i="$(_nix_stable_index)"
        [[ -f flake.lock.stable.$i ]] || { print -r -- "No flake.lock.stable.$i"; return 1; }
        diff -u "flake.lock.stable.$i" flake.lock | less
      }
      nix-stable-status() {
        cd "${projectdir}" || return 1
        local i s
        i="$(_nix_stable_index)"
        print -r -- "Active stable slot: $i  (state: ''${HOME}/.config/teonix/active-stable-${flakeAttr})"
        for s in 1 2 3 4; do
          if [[ -f flake.lock.stable.$s ]]; then
            print -r -- "  slot $s: present"
          else
            print -r -- "  slot $s: (empty)"
          fi
        done
        if [[ -f flake.lock.stable.$i ]]; then
          if diff -q "flake.lock.stable.$i" flake.lock >/dev/null 2>&1; then print -r -- "flake.lock matches active stable"; else print -r -- "flake.lock differs from active stable"; fi
        fi
      }

      alias hfsave='hyprflow save'
      alias hfrestore='hyprflow restore'
      alias hflist='hyprflow list'
      alias hfstatus='systemctl --user status hyprflow-autosave.timer'

      alias mvpn='mullvad status'
      alias mvpnon='mullvad connect'
      alias mvpnoff='mullvad disconnect'
      alias mvpnse='mullvad relay set location se sto && mullvad connect'
      alias mvpnus='mullvad relay set location us && mullvad connect'
      alias mvpngui='mullvad-vpn'
    '';
  };
}
