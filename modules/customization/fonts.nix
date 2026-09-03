{ config, pkgs, ... }:

{
    fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      font-awesome         # Icon font
      noto-fonts
      liberation_ttf
      source-han-serif
      ibm-plex
      _3270font
      # Michroma — wide Eurostile-style corporate sans (OFL). Regular only.
      (stdenvNoCC.mkDerivation {
        pname = "michroma";
        version = "1.000";
        src = ./fonts/Michroma-Regular.ttf;
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/share/fonts/truetype
          cp $src $out/share/fonts/truetype/Michroma-Regular.ttf
        '';
      })
      # VT323 — VT320/Matrix CRT face (OFL). Qt font.family is one name, not CSS.
      (stdenvNoCC.mkDerivation {
        pname = "vt323";
        version = "2.000";
        src = ./fonts/VT323-Regular.ttf;
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/share/fonts/truetype
          cp $src $out/share/fonts/truetype/VT323-Regular.ttf
        '';
      })
      (stdenvNoCC.mkDerivation {
        pname = "share-tech-mono";
        version = "1.002";
        src = ./fonts/ShareTechMono-Regular.ttf;
        dontUnpack = true;
        installPhase = ''
          mkdir -p $out/share/fonts/truetype
          cp $src $out/share/fonts/truetype/ShareTechMono-Regular.ttf
        '';
      })
    ];
    fontconfig = {
      defaultFonts = {
        sansSerif = [ "Michroma" "IBM Plex Sans" "Noto Sans" ];
        emoji = [ "Apple Color Emoji" ];
      };
      localConf = ''
        <!-- TODO
        ! Match on "color" and alias B&W ones first if no color is requested.
        ! That's "hard" because <alias> doesn't work in match and needs to be
        ! expanded to its non-sugar form.
        !-->
        <alias binding="same">
          <family>emoji</family>
          <prefer>
            <!-- System fonts -->
            <family>Apple Color Emoji</family> <!-- Apple -->
          </prefer>
        </alias>
      '';
    };
  };
}
