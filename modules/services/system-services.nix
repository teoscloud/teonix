{ config, pkgs, lib, ... }:

{
  # exFAT/vfat mount options for udisks2 (numeric uid/gid; $UID/$GID are not expanded by udisks2 in all contexts)
  environment.etc."udisks2/mount_options.conf" = {
    text = ''
      [defaults]
      exfat_defaults=uid=1000,gid=1000,iocharset=utf8,errors=remount-ro,dmask=0002,fmask=0113
      exfat_allow=uid,gid,iocharset,errors,dmask,fmask,namecase,umask
      vfat_defaults=uid=1000,gid=1000,dmask=0002,fmask=0113,shortname=mixed,utf8=1,flush
      vfat_allow=uid,gid,dmask,fmask,iocharset,shortname,utf8,flush
    '';
    mode = "0644";
  };

  services = {
    # nixpkgs defaults to dbus-broker; a live `nixos-rebuild switch` from classic dbus is blocked
    # (switchInhibitors). Pin classic dbus so `switch` / `systemupdate` keep working. To migrate to
    # broker later: delete this line, then `sudo nixos-rebuild boot --flake …` and reboot.
    dbus.implementation = "dbus";

    # Freedesktop Secret Service for Mailspring, browsers, etc. (not KWallet).
    gnome.gnome-keyring.enable = true;

    # Display Manager - GDM; session picker includes Plasma + GNOME + Hyprland
    displayManager = {
      gdm.enable = true;
      defaultSession = "gnome";
    };

    # Desktop Managers - KDE Plasma 6 + GNOME (Hyprland is via programs.hyprland)
    desktopManager = {
      plasma6 = {
        enable = true;
        enableQt5Integration = true;  # Enable Qt5 integration for compatibility
      };
      gnome.enable = true;
    };
    
    # Enable sound with Pipewire
    pulseaudio.enable = false; 
    
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
      # Keep USB interfaces hot (no auto-suspend) for low-latency audio work.
      wireplumber.extraConfig."99-usb-audio-no-suspend" = {
        "monitor.alsa.rules" = [
          {
            matches = [
              { "node.name" = "~alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC.*"; }
              { "node.name" = "~alsa_output.usb-Burr-Brown_from_TI_USB_Audio_CODEC.*"; }
              { "node.name" = "~alsa_input.usb-Focusrite_Scarlett_2i4_USB.*"; }
              { "node.name" = "~alsa_output.usb-Focusrite_Scarlett_2i4_USB.*"; }
            ];
            actions = {
              update-props = {
                "session.suspend-timeout-seconds" = 0;
                "node.pause-on-idle" = false;
              };
            };
          }
        ];
      };
      # Chromium/Brave silent audio (NullAudioSink, no Pulse stream):
      # 1) WP restoring per-app target.object to dead sink names
      # 2) Session default sink at extreme rates (e.g. 384 kHz) — Chromium refuses to open
      # Do not pin browser streams to saved targets; browsers follow a usable default / PULSE_SINK.
      wireplumber.extraConfig."99-no-stale-stream-targets" = {
        "wireplumber.settings" = {
          "node.stream.restore-target" = false;
        };
        # Per-stream: never save/restore sink targets for browsers (follow default only).
        "stream.rules" = [
          {
            matches = [ { "application.name" = "Brave"; } ];
            actions = {
              update-props = {
                "state.restore-target" = false;
              };
            };
          }
          {
            matches = [ { "application.name" = "Chromium"; } ];
            actions = {
              update-props = {
                "state.restore-target" = false;
              };
            };
          }
          {
            matches = [ { "application.name" = "Google Chrome"; } ];
            actions = {
              update-props = {
                "state.restore-target" = false;
              };
            };
          }
          {
            matches = [ { "application.name" = "firefox"; } ];
            actions = {
              update-props = {
                "state.restore-target" = false;
              };
            };
          }
          # PipeWire match regex has no (?i); list binaries explicitly.
          {
            matches = [ { "application.process.binary" = "brave"; } ];
            actions = {
              update-props = {
                "state.restore-target" = false;
              };
            };
          }
          {
            matches = [ { "application.process.binary" = "chrome"; } ];
            actions = {
              update-props = {
                "state.restore-target" = false;
              };
            };
          }
          {
            matches = [ { "application.process.binary" = "chromium"; } ];
            actions = {
              update-props = {
                "state.restore-target" = false;
              };
            };
          }
          {
            matches = [ { "application.process.binary" = "firefox"; } ];
            actions = {
              update-props = {
                "state.restore-target" = false;
              };
            };
          }
          {
            matches = [ { "application.process.binary" = "zen"; } ];
            actions = {
              update-props = {
                "state.restore-target" = false;
              };
            };
          }
        ];
      };
    };
    

    flatpak.enable = true;
    ratbagd.enable = true;
    spice-vdagentd.enable = true;

    udisks2.enable = true;
    printing.enable = true;

    # hypridle: started by exec-once in hyprland.conf, not as a system service
    # (system service starts at GDM before any compositor is running → errors)
    # mkForce: hyprlock module also sets this to true; we override it
    hypridle.enable = lib.mkForce false;

    xserver = {
      enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
      videoDrivers = [ "amdgpu" ];
    };

  };

  # RealtimeKit
  security.rtkit.enable = true;

  # Unlock login keyring at GDM / console login (Hyprland sessions included).
  # gdm-password (the real password-auth service) does `substack login`, so the keyring
  # module in `login` is what actually unlocks/creates the keyring at GDM login.
  security.pam.services = {
    gdm.enableGnomeKeyring = true;
    login.enableGnomeKeyring = true;
  };

  programs.seahorse.enable = true;

  services.dbus.packages = [ pkgs.gnome-keyring ];
}
