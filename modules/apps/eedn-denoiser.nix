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

  meta = with lib; {
    description = "Bertom-style zero-latency multiband denoiser (LV2 + LADSPA)";
    license = licenses.mit;
    platforms = platforms.linux;
  };
}
