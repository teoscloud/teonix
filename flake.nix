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
    username = "teodor";  # Global username variable
    hostname = "nixbox";  # Define hostname here

    stable-pkgs = import nixos-stable {
      inherit system;
      config.allowUnfree = true; 
    };

    unstable-pkgs = import nixos-unstable {
      inherit system;
      config.allowUnfree = true; 
    };

  in {
    nixosConfigurations = {
      nixbox = nixos-unstable.lib.nixosSystem {
        inherit system;

        specialArgs = {
          inherit stable-pkgs unstable-pkgs inputs nix-gaming username;
          hostname = "nixbox";  
        };

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

          # ✅ Add Home Manager at System Level
          inputs.home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = { inherit username hostname; };
            home-manager.users.${username} = import ./home/${username}.nix;
          }
        ];
      };
    };

    # ✅ Add Home Manager as a Standalone Flake
    homeConfigurations = {
      teodor = home-manager.lib.homeManagerConfiguration {
        pkgs = unstable-pkgs;  # ✅ Removed `system`

        extraSpecialArgs = {
          inherit username;
        };

        modules = [
          ./home/${username}.nix
        ];
      };
    };
  };
}
