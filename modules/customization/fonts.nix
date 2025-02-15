{ config, pkgs, ... }:

{
  fonts = {
    packages = with pkgs; [
      nerd-fonts.fira-code
      font-awesome         # Icon font
      noto-fonts
      liberation_ttf
    ];
    # prefer apple only
    fontconfig = {
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
