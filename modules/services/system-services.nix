{ config, ... }:

{
  services = {
    xserver = {
      enable = true;
      displayManager.gdm.enable = true;
      desktopManager.gnome.enable = true;
      xkb = {
        layout = "us";
        variant = "";
      };
      videoDrivers = [ "amdgpu" ];
    };

    printing.enable = true;
    pipewire = {
      enable = true;
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse.enable = true;
    };

    # Enable sound with Pipewire
    pulseaudio.enable = false; 

    flatpak.enable = true;
    ratbagd.enable = true;
    spice-vdagentd.enable = true;

    # hypridle for hyprland
    hypridle.enable = true;

  };

  # RealtimeKit
  security.rtkit.enable = true;

}
