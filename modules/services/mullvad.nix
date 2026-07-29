{ config, pkgs, ... }:

{
  # Mullvad DNS only works reliably with systemd-resolved on NixOS.
  services.resolved.enable = true;
  networking.networkmanager.dns = "systemd-resolved";

  # Daemon/CLI = pkgs.mullvad (default). GUI is a separate package now.
  services.mullvad-vpn = {
    enable = true;
    gui.enable = true;
  };

  # First boot after install: keep LAN + internet usable until you log in
  # and connect. Does not re-apply on later boots (marker file).
  systemd.services.mullvad-desktop-defaults = {
    description = "Apply one-time Mullvad desktop defaults (LAN on, lockdown off)";
    after = [ "mullvad-daemon.service" ];
    requires = [ "mullvad-daemon.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "mullvad-desktop-defaults" ''
        set -euo pipefail
        mullvad="${config.services.mullvad-vpn.package}/bin/mullvad"
        marker="/var/lib/mullvad-vpn/.nixos-desktop-defaults-applied"

        for _ in $(seq 1 45); do
          if "$mullvad" status >/dev/null 2>&1; then
            break
          fi
          sleep 1
        done

        if [ -f "$marker" ]; then
          exit 0
        fi

        "$mullvad" lockdown-mode set off || true
        "$mullvad" lan set allow || true
        mkdir -p /var/lib/mullvad-vpn
        touch "$marker"
      '';
    };
  };
}
