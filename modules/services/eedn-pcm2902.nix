{ pkgs, ... }:

let
  # Self-contained: sources live in the flake under vendor/
  eednSrc = ../../vendor/eedn-denoiser;

  eedn-denoiser = pkgs.callPackage ../apps/eedn-denoiser.nix {
    src = eednSrc;
  };

  userConfRel = ".config/pipewire/filter-chain.conf.d/eedn-pcm2902-mic.conf";

  # Tuned PCM2902 → EEDN → Easy Effects (see easyeffectsdenoiser HANDOVER.md)
  # Seeded once into ~/.config so the tuner GUI can edit on the fly.
  eednPcm2902Conf = pkgs.writeText "eedn-pcm2902-mic.conf" ''
    # Denoise the PCM2902 microphone, then hand off to Easy Effects.
    # Preset: UserTuned (from live tuner session).

    context.properties = {
        log.level = 2
    }

    context.spa-libs = {
        audio.convert.* = audioconvert/libspa-audioconvert
        support.*       = support/libspa-support
    }

    context.modules = [
        { name = libpipewire-module-rt
          args = {
              nice.level    = -11
              rt.prio       = 88
              rt.time.soft  = 200000
              rt.time.hard  = 200000
          }
          flags = [ ifexists nofail ]
        }
        { name = libpipewire-module-protocol-native }
        { name = libpipewire-module-client-node }
        { name = libpipewire-module-adapter }
        { name = libpipewire-module-metadata }

        { name = libpipewire-module-filter-chain
          args = {
              node.description = "EEDN PCM2902 Mic"
              media.name       = "EEDN PCM2902 Mic"
              filter.graph = {
                  nodes = [
                      {
                          type   = ladspa
                          name   = eedn
                          plugin = eedn_denoiser
                          label  = eedn_denoiser
                          control = {
                              "Threshold (dB)"     = -44.1146
                              "Range Band 1 (dB)"  = 12
                              "Range Band 2 (dB)"  = 11.5
                              "Range Band 3 (dB)"  = 8
                              "Range Band 4 (dB)"  = 14
                              "Range Band 5 (dB)"  = 12.5115
                              "Range Band 6 (dB)"  = 15.0295
                              "Band 1 Freq (Hz)"   = 120
                              "Band 2 Freq (Hz)"   = 240
                              "Band 3 Freq (Hz)"   = 600
                              "Band 4 Freq (Hz)"   = 1580
                              "Band 5 Freq (Hz)"   = 3000
                              "Band 6 Freq (Hz)"   = 12000
                              "HF Bias"            = 0.4
                              "Stereo Link"        = 0.9
                              "Bypass"             = 0.0
                          }
                      }
                  ]
              }
              capture.props = {
                  node.name         = "eedn_pcm2902_capture"
                  node.description  = "EEDN ← PCM2902 mic"
                  media.class       = "Stream/Input/Audio"
                  audio.channels    = 2
                  audio.position    = [ FL FR ]
                  target.object     = "alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC-00.analog-stereo-input"
                  stream.dont-remix = true
              }
              playback.props = {
                  node.name        = "eedn_pcm2902_playback"
                  node.description = "EEDN PCM2902 (denoised)"
                  media.name       = "EEDN PCM2902 (denoised)"
                  media.class      = "Stream/Output/Audio"
                  audio.channels   = 2
                  audio.position   = [ FL FR ]
                  target.object    = "easyeffects_sink"
                  node.passive     = true
              }
          }
        }
    ]
  '';

  # Copy measured defaults into ~/.config only if missing (never overwrite tuner edits).
  seedUserConf = pkgs.writeShellScript "eedn-seed-user-conf" ''
    set -euo pipefail
    conf="$HOME/${userConfRel}"
    mkdir -p "$(dirname "$conf")"
    if [[ ! -f "$conf" ]]; then
      cp ${eednPcm2902Conf} "$conf"
      chmod u+w "$conf"
    fi
  '';

  eednTunerPython = pkgs.python3.withPackages (ps: [ ps.tkinter ]);

  eedn-tuner = pkgs.writeShellApplication {
    name = "eedn-tuner";
    runtimeInputs = [ eednTunerPython pkgs.systemd ];
    text = ''
      ${seedUserConf}
      exec ${eednTunerPython}/bin/python3 ${eednSrc}/gui/eedn_tuner.py "$@"
    '';
  };

  eednTunerDesktop = pkgs.makeDesktopItem {
    name = "eedn-tuner";
    desktopName = "EEDN Tuner";
    comment = "Tune PCM2902 EEDN denoise bands and restart the filter-chain";
    exec = "eedn-tuner";
    categories = [ "Audio" "AudioVideo" "Settings" ];
    terminal = false;
  };
in
{
  # LADSPA/LV2 + on-the-fly tuner UI
  environment.systemPackages = [
    eedn-denoiser
    eedn-tuner
    eednTunerDesktop
  ];

  # Keep PCM2902 hot so the filter-chain can always grab capture
  services.pipewire.wireplumber.extraConfig."99-pcm2902-no-suspend" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          { "node.name" = "~alsa_input.usb-Burr-Brown_from_TI_USB_Audio_CODEC.*"; }
          { "node.name" = "~alsa_output.usb-Burr-Brown_from_TI_USB_Audio_CODEC.*"; }
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

  systemd.user.services.eedn-pcm2902 = {
    description = "EEDN denoise for PCM2902 mic → Easy Effects";
    after = [
      "pipewire.service"
      "pipewire-pulse.service"
      "easyeffects.service"
    ];
    wants = [ "pipewire.service" ];
    bindsTo = [ "pipewire.service" ];
    conflicts = [ "pcm2902-listen.service" ];
    wantedBy = [ "default.target" ];
    serviceConfig = {
      Type = "simple";
      Environment = [
        "LADSPA_PATH=${eedn-denoiser}/lib/ladspa"
        "LV2_PATH=${eedn-denoiser}/lib/lv2"
      ];
      # Seed writable conf (measured preset) once, then run from ~/.config so the UI can edit it.
      ExecStartPre = [
        "${seedUserConf}"
        "-${pkgs.systemd}/bin/systemctl --user stop pcm2902-listen.service"
      ];
      ExecStart = "${pkgs.pipewire}/bin/pipewire -c %h/${userConfRel}";
      Restart = "on-failure";
      RestartSec = 2;
    };
  };
}
