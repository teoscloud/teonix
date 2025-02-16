{
  description = "Teos NixOS configuration with flakes";

  inputs = {
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    nixos-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos-stable.url = "nixpkgs/nixos-24.05";  
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    nix-gaming.url = "github:fufexan/nix-gaming";
    hyprlux.url = "github:amadejkastelic/Hyprlux";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixos-unstable";
  };

  outputs = { self, nixos-stable, nixos-unstable, chaotic, nix-gaming, home-manager, ... } @ inputs:
  let
    system = "x86_64-linux"; 
    username = "teodor";  
    projectdir = "/home/${username}/teonix"; 

    # ✅ Define hostnames
    nixbox_hostname = "nixbox";
    nixtop_hostname = "nixtop";

    # ✅ Dynamically detect the hostname (fallback to `default` if unknown)
    detectedHostname = builtins.getEnv "HOSTNAME";
    defaultHostname = if builtins.elem detectedHostname [nixbox_hostname nixtop_hostname]
                      then detectedHostname
                      else "nixos";

    # ✅ Define package sources
    unstable-pkgs = import nixos-unstable {
      inherit system;
      config.allowUnfree = true; 
    };

    stable-pkgs = import nixos-stable {
      inherit system;
      config.allowUnfree = true; 
    };

    # ✅ Common arguments for all systems
    commonSpecialArgs = { inherit username projectdir inputs unstable-pkgs stable-pkgs; };

    # ✅ Dynamically set hardware configuration path
    hardwareConfigPath = if builtins.pathExists ./hosts/${detectedHostname}/hardware-configuration.nix
                         then ./hosts/${detectedHostname}/hardware-configuration.nix
                         else "/etc/nixos/hardware-configuration.nix";  # Fallback

  in {
    nixosConfigurations = {
      # ✅ NIXBOX (Desktop)
      nixbox = nixos-unstable.lib.nixosSystem {
        inherit system;
        specialArgs = commonSpecialArgs // { hostname = nixbox_hostname; };
        modules = [
          ./modules/core/kernel.nix
          ./modules/core/bootloader.nix
          ./modules/core/nix-settings.nix
          ./modules/core/users.nix
          ./hosts/nixbox/hardware-configuration.nix
          ./hosts/nixbox/gpuisolate.nix
          ./hosts/nixbox/edidpatch/edidpatch.nix
          ./hosts/nixbox/edidpatch/kernel-settings.nix
          ./modules/hardware/hardware.nix
          ./modules/env/environment.nix
          ./modules/apps/packages.nix
          ./modules/apps/programs.nix
          ./modules/apps/zoom.nix
          ./modules/customization/fonts.nix
          ./modules/customization/localization.nix
          ./modules/services/virtualisation.nix
          ./modules/services/networking.nix
          ./modules/services/system-services.nix
          ./modules/services/user-services.nix
          ./modules/services/xdgportal.nix
          ./modules/config/hyprluxconf.nix
          inputs.hyprlux.nixosModules.default
          chaotic.nixosModules.default

          # ✅ Home Manager for nixbox
          inputs.home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = commonSpecialArgs // { hostname = nixbox_hostname; };
            home-manager.users.${username} = import ./home/nixbox.nix;
          }
        ];
      };

      # ✅ NIXTOP (Laptop)
      nixtop = nixos-unstable.lib.nixosSystem {
        inherit system;
        specialArgs = commonSpecialArgs // { hostname = nixtop_hostname; };
        modules = [
          ./modules/core/kernel.nix
          ./modules/core/bootloader.nix
          ./modules/core/nix-settings.nix
          ./modules/core/users.nix
          ./hosts/nixtop/hardware-configuration.nix
          ./modules/hardware/hardware.nix
          ./modules/env/environment.nix
          ./modules/apps/packages.nix
          ./modules/apps/programs.nix
          ./modules/apps/zoom.nix
          ./modules/customization/fonts.nix
          ./modules/customization/localization.nix
          ./modules/services/virtualisation.nix
          ./modules/services/networking.nix
          ./modules/services/system-services.nix
          ./modules/services/user-services.nix
          ./modules/services/xdgportal.nix
          ./modules/config/hyprluxconf.nix
          inputs.hyprlux.nixosModules.default
          chaotic.nixosModules.default

          # ✅ Home Manager for nixtop
          inputs.home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = commonSpecialArgs // { hostname = nixtop_hostname; };
            home-manager.users.${username} = import ./home/nixtop.nix;
          }
        ];
      };

      # ✅ DEFAULT HOST (Fallback)
      default = nixos-unstable.lib.nixosSystem {
        inherit system;
        specialArgs = commonSpecialArgs // { hostname = defaultHostname; };
        modules = [
          ./modules/core/kernel.nix
          ./modules/core/bootloader.nix
          ./modules/core/nix-settings.nix
          ./modules/core/users.nix
          hardwareConfigPath  # ✅ Uses dynamically detected hardware config
          ./modules/hardware/hardware.nix
          ./modules/env/environment.nix
          ./modules/apps/packages.nix
          ./modules/apps/programs.nix
          ./modules/apps/zoom.nix
          ./modules/customization/fonts.nix
          ./modules/customization/localization.nix
          ./modules/services/virtualisation.nix
          ./modules/services/networking.nix
          ./modules/services/system-services.nix
          ./modules/services/user-services.nix
          ./modules/services/xdgportal.nix
          ./modules/config/hyprluxconf.nix
          inputs.hyprlux.nixosModules.default
          chaotic.nixosModules.default

          # ✅ Home Manager for Default Host
          inputs.home-manager.nixosModules.home-manager {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = commonSpecialArgs // { hostname = defaultHostname; };
            home-manager.users.${username} = import ./home/default.nix;
          }
        ];
      };
    };

    # ✅ Home Manager Configurations
    homeConfigurations = {
      nixbox = home-manager.lib.homeManagerConfiguration {
        pkgs = unstable-pkgs;
        extraSpecialArgs = commonSpecialArgs // { hostname = nixbox_hostname; };  
        modules = [ ./home/nixbox.nix ];
      };

      nixtop = home-manager.lib.homeManagerConfiguration {
        pkgs = unstable-pkgs;
        extraSpecialArgs = commonSpecialArgs // { hostname = nixtop_hostname; };  
        modules = [ ./home/nixtop.nix ];
      };

      default = home-manager.lib.homeManagerConfiguration {
        pkgs = unstable-pkgs;
        extraSpecialArgs = commonSpecialArgs // { hostname = defaultHostname; };  
        modules = [ ./home/default.nix ];
      };
    };
  };
}
