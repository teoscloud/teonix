# One Secret Service for every desktop on this machine: GNOME Keyring.
# KDE's ksecretd is started by Plasma PAM and lingers on the user bus, so
# browsers and Electron apps either talk to KWallet or find no provider
# after a Hyprland login — "keyring missing / failed to unlock" popups.
# Nixbox already pins gnome-keyring system-wide; Fedora has to do it in
# Home Manager + fedora.sh (host PAM unlocks the login keyring).
{
  config,
  pkgs,
  lib,
  ...
}:

let
  keyringDaemon = pkgs.writeShellScript "teonix-keyring-daemon" ''
    set -eu
    for c in /usr/bin/gnome-keyring-daemon ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon; do
      if [ -x "$c" ]; then
        exec "$c" "$@"
      fi
    done
    echo "teonix-secrets: gnome-keyring-daemon missing — run: bash ~/teonix/hosts/applenix/fedora.sh" >&2
    exit 1
  '';

  secretsEnsure = pkgs.writeShellScriptBin "teonix-secrets-ensure" ''
    set +e
    # Plasma PAM starts ksecretd --pam-login; it survives into Hyprland on
    # the lingering user@ session and either owns org.freedesktop.secrets
    # or leaves the name unowned. Drop it so gnome-keyring can be the only
    # provider, in every DE.
    if command -v pkill >/dev/null; then
      pkill -x ksecretd >/dev/null 2>&1
      pkill -x kwalletd6 >/dev/null 2>&1
      pkill -x kwalletd5 >/dev/null 2>&1
    fi

    daemon=""
    for c in /usr/bin/gnome-keyring-daemon ${pkgs.gnome-keyring}/bin/gnome-keyring-daemon; do
      if [ -x "$c" ]; then
        daemon=$c
        break
      fi
    done
    if [ -z "$daemon" ]; then
      echo "teonix-secrets: gnome-keyring-daemon missing — run fedora.sh keyring step" >&2
      exit 0
    fi

    # --start joins a PAM-unlocked daemon or starts one. Never --replace:
    # that would drop the unlocked login keyring and prompt again.
    eval "$("$daemon" --start --components=pkcs11,secrets,ssh 2>/dev/null)"
    if [ -n "''${SSH_AUTH_SOCK:-}" ]; then
      ${pkgs.systemd}/bin/systemctl --user import-environment SSH_AUTH_SOCK GNOME_KEYRING_CONTROL >/dev/null 2>&1 || true
    fi
    exit 0
  '';
in
{
  home.packages = [
    secretsEnsure
    pkgs.gnome-keyring
    pkgs.libsecret
    pkgs.seahorse
  ];

  # D-Bus activation prefers the user service over /usr/share (KWallet).
  xdg.dataFile."dbus-1/services/org.freedesktop.secrets.service".text = ''
    [D-BUS Service]
    Name=org.freedesktop.secrets
    Exec=${keyringDaemon} --foreground --components=secrets
  '';

  # No KWallet first-use wizard, and do not let it implement Secret Service.
  xdg.configFile."kwalletrc".text = ''
    [Wallet]
    Enabled=false
    First Use=false
    Close When Idle=false
    Close When Unused=false
  '';

  # Plasma's PAM helper respawns ksecretd; drop-in so we do not replace the
  # unit file, only its ExecStart.
  xdg.configFile."systemd/user/plasma-kwallet-pam.service.d/teonix.conf".text = ''
    [Service]
    ExecStart=
    ExecStart=${pkgs.coreutils}/bin/true
  '';

  systemd.user.services.teonix-secrets = {
    Unit = {
      Description = "GNOME Keyring as the only Freedesktop Secret Service";
      After = [ "graphical-session-pre.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe secretsEnsure}";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  home.sessionVariables = {
    # Chromium/Electron honour this when not passed --password-store.
    CHROME_PASSWORD_STORE = "gnome-libsecret";
    PASSWORD_STORE = "gnome";
  };

  xdg.portal.extraPortals = [ pkgs.gnome-keyring ];
}
