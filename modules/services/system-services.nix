{ config, ... }:

{
  services = {
    # Display Manager - SDDM for KDE Plasma
    # Note: Having both SDDM and GDM enabled can cause conflicts
    # SDDM is recommended for KDE Plasma, GDM for GNOME/Hyprland
    # You can choose one by commenting out the other
    displayManager = {
      sddm = {
        enable = true;
        wayland.enable = true;  # Enable Wayland support
      };
      # Set default session to Plasma (optional - SDDM will show all available sessions)
      defaultSession = "plasma";
      # Uncomment below if you want GDM instead (for GNOME/Hyprland)
      # gdm.enable = true;
    };

    # Desktop Managers - KDE Plasma 6
    desktopManager = {
      plasma6 = {
        enable = true;
        enableQt5Integration = true;  # Enable Qt5 integration for compatibility
      };
      # Uncomment below if you want GNOME as well
      # gnome.enable = true;
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
    };
    

    flatpak.enable = true;
    ratbagd.enable = true;
    spice-vdagentd.enable = true;

    udisks2.enable = true;
    printing.enable = true;

    # hypridle for hyprland
    hypridle.enable = true;

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

}
