{ config, pkgs, lib, ... }:

{
  # KDE Plasma Desktop Environment - Additional Services and Configuration
  # Note: Display manager (SDDM) and desktop manager (plasma6) are configured in system-services.nix
  
  services = {
    # KDE-specific services
    dbus.packages = [ pkgs.kdePackages.kde-cli-tools ];
    
    # KDE requires these for proper functionality
    accounts-daemon.enable = true;
    geoclue2.enable = true;
    
    # Enable KDE's power management
    power-profiles-daemon.enable = true;
    
    # Note: Baloo (file indexing) is no longer a separate service in newer NixOS versions
    # It's managed directly by KDE Plasma if needed
  };

  # KDE Plasma environment variables and packages
  environment = {
    # Add KDE applications to PATH
    systemPackages = with pkgs; [
      kdePackages.kde-cli-tools
      kdePackages.kdegraphics-thumbnailers
      kdePackages.ffmpegthumbs
      kdePackages.kio-extras
      kdePackages.kio-gdrive
      kdePackages.kio-zeroconf
      kdePackages.kdeconnect-kde
      kdePackages.kdeplasma-addons
      kdePackages.plasma-browser-integration
      # Note: qtstyleplugins may not be available in this nixpkgs version
    ];

    # Plasma-specific environment variables
    # Note: XDG_SESSION_DESKTOP and XDG_CURRENT_DESKTOP are set automatically by KDE Plasma
    # when you start a Plasma session, so we don't set them here to avoid conflicts with Hyprland
    sessionVariables = {
      # Qt platform theme for KDE applications (works in both Hyprland and Plasma)
      QT_QPA_PLATFORMTHEME = "kde";
    };
  };

  # XDG Desktop Portal configuration for KDE
  # This works alongside the existing xdgportal.nix configuration
  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      kdePackages.xdg-desktop-portal-kde
    ];
    # Use KDE's portal implementation
    configPackages = [ pkgs.kdePackages.xdg-desktop-portal-kde ];
    # Prefer KDE portals in Plasma sessions (Hyprland uses hyprland+gtk from xdgportal.nix)
    config.plasma.default = [ "kde" "gtk" ];
  };

  # Hardware support for KDE
  hardware = {
    # Enable Bluetooth for KDE Connect
    bluetooth.enable = true;
  };

  # Security policies for KDE
  security.polkit.enable = true;

  # Font configuration (KDE uses system fonts)
  # Note: Fonts are already configured elsewhere, so we don't add any here

  # Programs that work well with KDE
  programs = {
    # KDE Partition Manager
    partition-manager.enable = true;
    
    # KDE's file manager integration
    kdeconnect.enable = true;
    
    # Enable dconf for GTK apps in KDE
    dconf.enable = true;
  };
}
