{ config, pkgs, username, ... }:

{
  # vkBasalt - Vulkan post-processing layer for vibrance/saturation
  # Works with KDE Plasma, Hyprland, and any compositor
  # Provides digital vibrance for CS2 and other Vulkan games
  
  # vkBasalt package is already added in packages.nix
  # This module creates the configuration file and sets environment variables

  # Create the vkBasalt configuration directory and file on system activation
  system.activationScripts.vkbasalt-config = ''
    mkdir -p /home/${username}/.config/vkBasalt
    if [ ! -f /home/${username}/.config/vkBasalt/vkBasalt.conf ]; then
      cat > /home/${username}/.config/vkBasalt/vkBasalt.conf << 'VKBASALT_EOF'
# vkBasalt configuration for CS2 vibrance
# Documentation: https://github.com/DadSchoorse/vkBasalt

# Enable vkBasalt
enableVkBasalt = True

# Vibrance settings (0.0 = no change, 1.0 = maximum vibrance)
# Recommended: 0.3-0.5 for subtle enhancement, 0.5-0.8 for strong vibrance
# CS2 typically looks good with 0.5-0.7
vibrance = 0.6

# Contrast settings (optional, 0.0 = no change)
# contrast = 0.0

# Saturation settings (optional, 0.0 = no change)
# saturation = 0.0

# Enable for specific applications only (optional)
# toggleKey = Home

# Output color space (optional)
# outputColorSpace = 0

# CAS sharpening (optional, can improve image quality)
# cas = True
# casSharpness = 0.4
VKBASALT_EOF
      # Use just username - chown will automatically use the user's primary group
      chown ${username} /home/${username}/.config/vkBasalt/vkBasalt.conf
      chmod 644 /home/${username}/.config/vkBasalt/vkBasalt.conf
    fi
  '';

  # vkBasalt hooks all Vulkan apps when enabled — Chromium/Brave can crash or glitch.
  # Off by default; for games run: ENABLE_VKBASALT=1 steam %command% (or a wrapper script).
  environment.sessionVariables = {
    ENABLE_VKBASALT = "0";
    
    # Set the config file path explicitly
    VKBASALT_CONFIG_FILE = "/home/${username}/.config/vkBasalt/vkBasalt.conf";
  };
}
