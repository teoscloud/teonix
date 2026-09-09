{ pkgs, lib, ... }:

{
  # Latest LTS from nixpkgs (linuxPackages), not CachyOS and not mainline
  # linuxPackages_latest. Point releases ride along with flake updates.
  boot.kernelPackages = lib.mkForce pkgs.linuxPackages;

  boot.kernelParams = [
    "intel_iommu=on"
    "iommu=pt"
  ];

  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
    options kvm ignore_msrs=1
  '';

  boot.kernel.sysctl = {
    "fs.inotify.max_user_watches" = 1048576;
    "fs.inotify.max_user_instances" = 1024;
    "fs.file-max" = 2097152;
    "kernel.pid_max" = 4194304;
  };
}
