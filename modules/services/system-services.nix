{ config, pkgs, lib, system ? "x86_64-linux", ... }:

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
    # mkForce: programs.uwsm (via programs.hyprland.withUWSM) asks for "broker"
    # outright; UWSM runs fine on classic dbus, it just handles the activation
    # environment itself.
    dbus.implementation = lib.mkForce "dbus";

    # Freedesktop Secret Service for Mailspring, browsers, etc. (not KWallet).
    gnome.gnome-keyring.enable = true;

    # Display Manager - GDM; session picker includes Plasma + GNOME + Hyprland.
    # No defaultSession on purpose: with it set, the NixOS GDM module runs
    # `set-session <default>` in display-manager's preStart, which overwrites
    # every user's AccountsService session record before each greeter start
    # ("basically ignore session history", per the module). Left unset, GDM
    # remembers whatever each user picked last, so a Hyprland (UWSM) login
    # stays the default login.
    displayManager = {
      gdm.enable = true;
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
        support32Bit = lib.mkIf (system == "x86_64-linux") true;
      };
      pulse.enable = true;
      # Keep USB interfaces hot (no auto-suspend) for low-latency audio work.
      wireplumber.extraConfig."99-usb-audio-no-suspend" = lib.mkIf (system == "x86_64-linux") {
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
      # Clock master. PipeWire drives the whole graph off one node, elected by
      # priority.driver, and WirePlumber hands capture nodes +1000 over playback.
      # So any capture device that is running (the PCM2902 codec feeding a
      # BusChain track, the webcam mic) out-ranks the Scarlett you listen on,
      # and the PCM2902 — a full-speed USB 1.1 codec that only does 48 kHz,
      # resampled to the forced 96 kHz graph — drops a period about once a
      # second, which every follower then hears as a flicker. Make the Scarlett
      # win the election outright and give the codec the slack it needs once
      # it is a follower.
      wireplumber.extraConfig."60-scarlett-clock-master" = lib.mkIf (system == "x86_64-linux") {
        "monitor.alsa.rules" = [
          {
            matches = [ { "api.alsa.card.name" = "Scarlett 2i4 USB"; } ];
            actions = {
              update-props = {
                "priority.driver" = 5000;
                "priority.session" = 5000;
              };
            };
          }
          {
            matches = [ { "api.alsa.card.name" = "USB Audio CODEC"; } ];
            actions = {
              update-props = {
                "priority.driver" = 100;
                "api.alsa.headroom" = 1024;
                "api.alsa.period-size" = 512;
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
      videoDrivers = lib.mkIf (system == "x86_64-linux") [ "amdgpu" ];
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
