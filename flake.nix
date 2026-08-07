{
  description = "Teos NixOS configuration with flakes";

  inputs = {
    # Use the unstable *channel* so Hydra binaries are available (nixpkgs/master
    # often forces multi-hour local Electron/Chromium/KDE builds with no cache hit).
    # Hyprland: stick to nixpkgs' package — do not pin Hyprland git main here.
    nixos-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos-stable.url = "nixpkgs/nixos-24.05";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    # Keep Chaotic on the same nixpkgs/HM as the system (avoids dual evaluation).
    chaotic.inputs.nixpkgs.follows = "nixos-unstable";
    chaotic.inputs.home-manager.follows = "home-manager";
    # Declared for cachix substituters in modules/core/nix-settings.nix (not imported as a module).
    nix-gaming.url = "github:fufexan/nix-gaming";
    hyprlux.url = "github:amadejkastelic/Hyprlux";
    hyprlux.inputs.nixpkgs.follows = "nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixos-unstable";
  };

  outputs = { self, nixos-stable, nixos-unstable, chaotic, nix-gaming, home-manager, ... } @ inputs:
  let
    system = "x86_64-linux";
    username = "teodor";
    projectdir = "/home/${username}/teonix";

    nixbox_hostname = "nixbox";
    nixtop_hostname = "nixtop";

    # Impure: needs --impure when HOSTNAME is used for the default host / hardware path.
    detectedHostname = builtins.getEnv "HOSTNAME";
    defaultHostname = if builtins.elem detectedHostname [ nixbox_hostname nixtop_hostname ]
                      then detectedHostname
                      else "nixos";

    # Keep overlays minimal — every overrideAttrs that changes a derivation hash
    # causes cache misses and local compiles for that package and its dependents.
    unstable-pkgs = import nixos-unstable {
      inherit system;
      config.allowUnfree = true;
      overlays = [ chaotic.overlays.default ];
    };

    stable-pkgs = import nixos-stable {
      inherit system;
      config.allowUnfree = true;
    };

    commonSpecialArgs = { inherit username projectdir inputs unstable-pkgs stable-pkgs; };

    hardwareConfigPath =
      if builtins.pathExists ./hosts/${detectedHostname}/hardware-configuration.nix
      then ./hosts/${detectedHostname}/hardware-configuration.nix
      else "/etc/nixos/hardware-configuration.nix";

    sharedModules = [
      ./modules/core/nix-settings.nix
      ./modules/core/kernel.nix
      ./modules/core/bootloader.nix
      ./modules/core/users.nix
      ./modules/hardware/hardware.nix
      ./modules/env/environment.nix
      ./modules/apps/packages.nix
      ./modules/apps/programs.nix
      ./modules/apps/zoom.nix
      ./modules/customization/fonts.nix
      ./modules/customization/localization.nix
      ./modules/services/virtualisation.nix
      ./modules/services/networking.nix
      ./modules/services/mullvad.nix
      ./modules/services/system-services.nix
      ./modules/services/plasma.nix
      ./modules/services/user-services.nix
      ./modules/services/xdgportal.nix
      ./modules/config/hyprluxconf.nix
      ./modules/config/vkbasalt.nix
    ];

    mkHomeManager = hostname: homeFile: [
      inputs.home-manager.nixosModules.home-manager
      {
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        # Existing files (e.g. ~/.zshrc) → ~/.zshrc.bak instead of aborting activation
        home-manager.backupFileExtension = "bak";
        home-manager.extraSpecialArgs = commonSpecialArgs // { inherit hostname; };
        home-manager.users.${username} = import homeFile;
      }
    ];

    mkNixos = { hostname, home, modules ? [] }: nixos-unstable.lib.nixosSystem {
      inherit system;
      specialArgs = commonSpecialArgs // { inherit hostname; };
      modules = sharedModules ++ modules ++ [
        inputs.hyprlux.nixosModules.default
        chaotic.nixosModules.default
      ] ++ (mkHomeManager hostname home);
    };
  in {
    nixosConfigurations = {
      nixbox = mkNixos {
        hostname = nixbox_hostname;
        home = ./home/nixbox.nix;
        modules = [
          ./hosts/nixbox/hardware-configuration.nix
          ./hosts/nixbox/nixconfig.nix
          # ./hosts/nixbox/gpuisolate.nix   # VFIO — enable when needed
          # ./hosts/nixbox/powerctrl.nix   # TLP — conflicts with power-profiles-daemon
          ./hosts/nixbox/ssh.nix
          ./hosts/nixbox/edidpatch/edidpatch.nix
          ./hosts/nixbox/edidpatch/kernel-settings.nix
          ./modules/services/gnome.nix
        ];
      };

      nixtop = mkNixos {
        hostname = nixtop_hostname;
        home = ./home/nixtop.nix;
        modules = [
          ./hosts/nixtop/hardware-configuration.nix
          ./hosts/nixtop/nixconfig.nix
          # ./hosts/nixtop/power.nix       # TLP — not imported; PPD used via plasma.nix
        ];
      };

      default = mkNixos {
        hostname = defaultHostname;
        home = ./home/default.nix;
        modules = [ hardwareConfigPath ];
      };
    };

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
