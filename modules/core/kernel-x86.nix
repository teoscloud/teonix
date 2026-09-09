{ config, pkgs, username, lib, hostname ? "", ... }:

{
  boot = {
    # CachyOS + AMD IOMMU are desktop hosts only. #mainframe sets
    # linuxPackages (LTS) / intel_iommu in hosts/mainframe/platform.nix.
    kernelPackages = lib.mkIf (hostname != "mainframe") (
      if pkgs ? linuxPackages_cachyos
      then pkgs.linuxPackages_cachyos
      else pkgs.linuxPackages
    );

    kernelParams = lib.optionals (hostname != "mainframe") [
      "amd_iommu=on"
      "iommu=pt"
    ];

    postBootCommands = ''
      touch /dev/shm/looking-glass
      chown ${username}:kvm /dev/shm/looking-glass
      chmod 660 /dev/shm/looking-glass
      chmod 666 /dev/input/by-id/usb-Logitech_USB_Receiver-if02-mouse 2>/dev/null || true
      chmod 666 /dev/input/event* 2>/dev/null || true
    '';
  };
}
