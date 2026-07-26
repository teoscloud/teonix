{ lib
, stdenv
, pkg-config
, lv2
, src
}:

stdenv.mkDerivation {
  pname = "eedn-denoiser";
  version = "1.0.0";

  inherit src;

  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ lv2 ];

  makeFlags = [ "PREFIX=$(out)" ];

  postPatch = ''
    rm -rf build .git
  '';

  # Ship filter-chain template + preset docs alongside the plugins.
  postInstall = ''
    mkdir -p $out/share/eedn-denoiser/presets $out/share/eedn-denoiser/pipewire
    cp -r presets/. $out/share/eedn-denoiser/presets/
    cp pipewire/eedn-pcm2902-mic.conf $out/share/eedn-denoiser/pipewire/
    cp pipewire/eedn-denoise-sink.conf $out/share/eedn-denoiser/pipewire/ 2>/dev/null || true
  '';

  meta = with lib; {
    description = "Bertom-style zero-latency multiband denoiser (LV2 + LADSPA)";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
