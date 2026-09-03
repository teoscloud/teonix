# PLACEHOLDER — replace after first install on the MacBook:
#   sudo nixos-generate-config --show-hardware-config > hosts/applenix/hardware-configuration.nix
#
# Partition UUIDs below are dummy values so the flake evaluates off-device.
{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [ "apple_soc_cpu" "apple_soc_pci" "apple_soc_nvme" "xhci_pci" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "brcmfmac" "brcmutil" "snd_soc_apple_mca" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/00000000-0000-4000-8000-000000000001";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/0000-0000";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [
    { device = "/dev/disk/by-uuid/00000000-0000-4000-8000-000000000002"; }
  ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
