{ config, pkgs, stable-pkgs, username, lib, ... }:

{
  boot = {
    supportedFilesystems = [ "exfat" ];

    # Choose the kernel from either stable or unstable as needed
    # Use CachyOS kernel if available (from chaotic overlay), otherwise fallback to default
    # The chaotic overlay is applied via nixpkgs.overlays in nix-settings.nix
    kernelPackages = if pkgs ? linuxPackages_cachyos 
                     then pkgs.linuxPackages_cachyos 
                     else pkgs.linuxPackages;

    kernelModules = [ "kvm" "exfat" ];

    # Needed For Some Steam Games
    kernel.sysctl = {
      "vm.max_map_count" = 2147483642;
    };

    kernelParams = [
      "hid_apple.fnmode=0"
      #"ipv6.disable=1"
      "amd_iommu=on"
      "iommu=pt"
    ];

    postBootCommands = ''
      # Setup Looking Glass shared memory object
      touch /dev/shm/looking-glass
      chown ${username}:kvm /dev/shm/looking-glass
      chmod 660 /dev/shm/looking-glass

      # Change permissions on input devices to allow full access
      chmod 666 /dev/input/by-id/usb-Logitech_USB_Receiver-if02-mouse
      chmod 666 /dev/input/event*
    '';
  };
}
