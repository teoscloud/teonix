{
  description = "Teos NixOS configuration with flakes";

  inputs = {
    nixos-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixos-stable.url = "nixpkgs/nixos-24.05";
    chaotic.url = "github:chaotic-cx/nyx/nyxpkgs-unstable";
    chaotic.inputs.nixpkgs.follows = "nixos-unstable";
    chaotic.inputs.home-manager.follows = "home-manager";
    nix-gaming.url = "github:fufexan/nix-gaming";
    hyprlux.url = "github:amadejkastelic/Hyprlux";
    hyprlux.inputs.nixpkgs.follows = "nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixos-unstable";
    # 2025-11-18 kernel config fails linux-config on nixpkgs 26.11 (unused
    # options such as JITTERENTROPY) → linux-asahi → applenix-26.11.
    apple-silicon.url = "github:nix-community/nixos-apple-silicon/release-2026-07-30";
    apple-silicon.inputs.nixpkgs.follows = "nixos-unstable";
  };

  outputs = { self, nixos-stable, nixos-unstable, chaotic, nix-gaming, home-manager, apple-silicon, ... } @ inputs:
  let
    username = "teodor";
    projectdir = "/home/${username}/teonix";

    nixbox_hostname = "nixbox";
    nixtop_hostname = "nixtop";
    applenix_hostname = "applenix";

    detectedHostname = builtins.getEnv "HOSTNAME";
    defaultHostname =
      if builtins.elem detectedHostname [ nixbox_hostname nixtop_hostname applenix_hostname ]
      then detectedHostname
      else "nixos";

    lib = nixos-unstable.lib;

    mkPkgs = system:
      let
        useChaotic = system == "x86_64-linux";
        overlays = lib.optional useChaotic chaotic.overlays.default;
      in import nixos-unstable {
        inherit system;
        config.allowUnfree = true;
        overlays = overlays;
      };

    x86Pkgs = mkPkgs "x86_64-linux";
    armPkgs = mkPkgs "aarch64-linux";

    pkgsFor = system:
      if system == "aarch64-linux" then armPkgs else x86Pkgs;

    stableFor = system:
      import nixos-stable {
        inherit system;
        config.allowUnfree = true;
      };

    mkCommonSpecialArgs = system:
      {
        inherit username projectdir inputs system;
        unstable-pkgs = pkgsFor system;
        stable-pkgs = stableFor system;
        apple-silicon = apple-silicon;
      };

    hardwareConfigPath =
      if builtins.pathExists ./hosts/${detectedHostname}/hardware-configuration.nix
      then ./hosts/${detectedHostname}/hardware-configuration.nix
      else "/etc/nixos/hardware-configuration.nix";

    sharedModules = system:
      [
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
        ./modules/config/vkbasalt.nix
      ]
      ++ lib.optionals (system == "x86_64-linux") [
        ./modules/apps/packages-x86.nix
        ./modules/config/hyprluxconf.nix
      ]
      ++ lib.optionals (system == "aarch64-linux") [
        ./modules/apps/packages-aarch64.nix
      ];

    mkHomeManager = system: hostname: homeFile:
      let
        commonSpecialArgs = mkCommonSpecialArgs system;
      in [
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "bak";
          home-manager.extraSpecialArgs = commonSpecialArgs // { inherit hostname; };
          home-manager.users.${username} = import homeFile;
        }
      ];

    mkNixos =
      {
        hostname,
        home,
        system ? "x86_64-linux",
        modules ? [],
        extraModules ? [],
      }:
      nixos-unstable.lib.nixosSystem {
        inherit system;
        specialArgs = mkCommonSpecialArgs system // { inherit hostname; };
        modules =
          sharedModules system
          ++ modules
          ++ extraModules
          ++ (mkHomeManager system hostname home);
      };

    x86ExtraModules = [
      inputs.hyprlux.nixosModules.default
      chaotic.nixosModules.default
    ];
  in {
    nixosConfigurations = {
      nixbox = mkNixos {
        system = "x86_64-linux";
        hostname = nixbox_hostname;
        home = ./home/nixbox.nix;
        extraModules = x86ExtraModules;
        modules = [
          ./hosts/nixbox/hardware-configuration.nix
          ./hosts/nixbox/nixconfig.nix
          ./hosts/nixbox/ssh.nix
          ./hosts/nixbox/edidpatch/edidpatch.nix
          ./hosts/nixbox/edidpatch/kernel-settings.nix
          ./modules/services/gnome.nix
        ];
      };

      nixtop = mkNixos {
        system = "x86_64-linux";
        hostname = nixtop_hostname;
        home = ./home/nixtop.nix;
        extraModules = x86ExtraModules;
        modules = [
          ./hosts/nixtop/hardware-configuration.nix
          ./hosts/nixtop/nixconfig.nix
        ];
      };

      default = mkNixos {
        system = "x86_64-linux";
        hostname = defaultHostname;
        home = ./home/default.nix;
        extraModules = x86ExtraModules;
        modules = [ hardwareConfigPath ];
      };

      applenix = mkNixos {
        system = "aarch64-linux";
        hostname = applenix_hostname;
        home = ./home/applenix.nix;
        modules = [
          ./hosts/applenix/asahi.nix
          ./hosts/applenix/hardware-configuration.nix
          ./hosts/applenix/nixconfig.nix
        ];
      };

      # Tiny first-boot system for the Asahi USB installer. See hosts/applenix/INSTALL.md
      applenix-bootstrap = nixos-unstable.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = mkCommonSpecialArgs "aarch64-linux" // { hostname = applenix_hostname; };
        modules = [
          ./hosts/applenix/asahi.nix
          ./hosts/applenix/hardware-configuration.nix
          ./hosts/applenix/bootstrap.nix
        ];
      };
    };

    homeConfigurations = {
      nixbox = home-manager.lib.homeManagerConfiguration {
        pkgs = x86Pkgs;
        extraSpecialArgs = mkCommonSpecialArgs "x86_64-linux" // { hostname = nixbox_hostname; };
        modules = [ ./home/nixbox.nix ];
      };

      nixtop = home-manager.lib.homeManagerConfiguration {
        pkgs = x86Pkgs;
        extraSpecialArgs = mkCommonSpecialArgs "x86_64-linux" // { hostname = nixtop_hostname; };
        modules = [ ./home/nixtop.nix ];
      };

      default = home-manager.lib.homeManagerConfiguration {
        pkgs = x86Pkgs;
        extraSpecialArgs = mkCommonSpecialArgs "x86_64-linux" // { hostname = defaultHostname; };
        modules = [ ./home/default.nix ];
      };

      applenix = home-manager.lib.homeManagerConfiguration {
        pkgs = armPkgs;
        extraSpecialArgs = mkCommonSpecialArgs "aarch64-linux" // { hostname = applenix_hostname; };
        modules = [ ./home/applenix.nix ];
      };
    };
  };
}
