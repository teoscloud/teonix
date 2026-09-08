# STUB so #mainframe evaluates on nixbox. On the installer USB, replace this
# file wholesale with `nixos-generate-config --root /mnt` output (see MIGRATE.md).
# Do not hand-merge disks vs chipset — the generated file is the source of truth.
{ config, lib, pkgs, modulesPath, username, ... }:

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix")
    ];

  boot.initrd.availableKernelModules = [ "nvme" "xhci_pci" "ahci" "usbhid" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/77da4a95-2958-4385-b35f-9c696d4f9618";
      fsType = "ext4";
    };

  fileSystems."/boot" =
    { device = "/dev/disk/by-uuid/547E-412E";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };

  fileSystems."/home/${username}/mnt/qvo870" =
    { device = "/dev/disk/by-uuid/c232ec48-5b23-4718-99de-77a7da454343";
      fsType = "ext4";
      options = [ "nofail" "x-systemd.device-timeout=2s" ];
    };

  fileSystems."/home/${username}/mnt/qvo860" =
    { device = "/dev/disk/by-uuid/b3ef6e32-cf62-487b-bc43-03edcfecef09";
      fsType = "ext4";
      options = [ "nofail" "x-systemd.device-timeout=2s" ];
    };

  swapDevices =
    [ { device = "/dev/disk/by-uuid/92bea4ff-dcf7-4201-a376-37c10bc4c7dc"; }
    ];

  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
