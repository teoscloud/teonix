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

    # ✅ Define separate hostnames for different machines
    nixbox_hostname = "nixbox";
    nixtop_hostname = "nixtop";

    # Define `unstable-pkgs`
    unstable-pkgs = import nixos-unstable {
      inherit system;
      config.allowUnfree = true; 
    };

    stable-pkgs = import nixos-stable {
      inherit system;
      config.allowUnfree = true; 
    };

    # Common arguments for both systems
    commonSpecialArgs = { inherit username projectdir inputs unstable-pkgs stable-pkgs; };

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
            home-manager.users.${username} = import ./home/${username}.nix;
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
            home-manager.users.${username} = import ./home/${username}.nix;
          }
        ];
      };
    };

    homeConfigurations = {
      ${nixbox_hostname} = home-manager.lib.homeManagerConfiguration {
        pkgs = unstable-pkgs;
        extraSpecialArgs = commonSpecialArgs // { hostname = nixbox_hostname; };
        modules = [
          ./home/${nixbox_hostname}.nix       # ✅ PC-specific modules
        ];
      };

      ${nixtop_hostname} = home-manager.lib.homeManagerConfiguration {
        pkgs = unstable-pkgs;
        extraSpecialArgs = commonSpecialArgs // { hostname = nixtop_hostname; };
        modules = [
          ./home/${nixtop_hostname}.nix  # ✅ Laptop-specific modules
        ];
      };

      teodor = home-manager.lib.homeManagerConfiguration {
        pkgs = unstable-pkgs;
        extraSpecialArgs = commonSpecialArgs // { hostname = nixbox_hostname; };  # ⚠️ Choose the hostname dynamically if needed
        modules = [ ./home/${username}.nix ];
      };
    };
  };
}
