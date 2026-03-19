{ config, ... }:

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

    # Desktop Managers - KDE Plasma 6 + GNOME (SDDM shows both sessions)
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
