# Minimal first-boot system. Installed from the Asahi NixOS USB with:
#   nixos-install --flake /mnt/home/teodor/teonix#applenix-bootstrap --impure
# After reboot, switch to the full rice: #applenix
{ pkgs, username, ... }:

{
  networking.hostName = "applenix";
  networking.networkmanager.enable = true;
  networking.networkmanager.wifi.backend = "iwd";
  networking.wireless.iwd.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = false;

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };

  nixpkgs.config.allowUnfree = true;

  users.mutableUsers = true;
  users.users.${username} = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "input" ];
    initialPassword = "teodor";
  };
  users.users.root.initialPassword = "teodor";

  environment.systemPackages = with pkgs; [
    git
    vim
    tmux
    curl
  ];

  zramSwap.enable = true;

  services.getty.helpLine = ''

    applenix bootstrap is up. Login: teodor / teodor  (change this now)
    Then:
      cd ~/teonix
      sudo nixos-rebuild switch --flake path:.#applenix --impure
  '';

  system.stateVersion = "24.05";
}
