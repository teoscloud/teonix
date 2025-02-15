{ config, pkgs, stable-pkgs, username, ... }:

{
  boot = {
    # Choose the kernel from either stable or unstable as needed
    kernelPackages = pkgs.linuxPackages_cachyos;

    #chaotic.scx.enable = true; # by default uses scx_rustland scheduler

    #kernelPackages = pkgs.linuxPackages_zen;
    

    #kernelPackages = pkgs.linuxPackages_xanmod_latest;

    # This is for OBS Virtual Cam Support
    kernelModules = [ "v4l2loopback" ];
    extraModulePackages = [ config.boot.kernelPackages.v4l2loopback ];
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
