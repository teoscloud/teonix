{ config, pkgs, ... }:

{
  systemd.user.services = {
    # ydotool needs a user daemon; used by ~/.config/hypr/scripts/ro-type.sh to send Ctrl+V
    # when pasting Romanian text into apps that ignore wtype’s virtual keyboard (Electron/XWayland).
    ydotoold = {
      enable = true;
      description = "ydotool daemon (uinput; ro-type.sh Ctrl+V fallback)";
      after = [ "graphical-session.target" ];
      wantedBy = [ "default.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.ydotool}/bin/ydotoold";
        Restart = "on-failure";
      };
    };

    mpris-proxy = {
      enable = true;
      description = "Mpris proxy";
      after = [ "network.target" "sound.target" ];
      wantedBy = [ "default.target" ];

      # Use stable bluez package
      serviceConfig.ExecStart = "${pkgs.bluez}/bin/mpris-proxy";
    };
  };
}
