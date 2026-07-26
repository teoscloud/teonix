{ pkgs, ... }:

let
  # Self-contained: sources live in the flake under vendor/
  eednSrc = ../../vendor/eedn-denoiser;

  eedn-denoiser = pkgs.callPackage ../apps/eedn-denoiser.nix {
    src = eednSrc;
  };

  userConfRel = ".config/pipewire/filter-chain.conf.d/eedn-pcm2902-mic.conf";

  # Preset: default — vendor template (live tuner session). Seeded once into
  # ~/.config so the tuner GUI can edit on the fly (never overwrite).
  eednPcm2902Conf = "${eednSrc}/pipewire/eedn-pcm2902-mic.conf";

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
      # Seed writable conf (default preset) once, then run from ~/.config so the UI can edit it.
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
