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

  # Hibernation target. hardware-configuration.nix is regenerated wholesale by the
  # installer and ships `swapDevices = [ ]`, so the swap partition is declared here
  # instead — otherwise it is only auto-activated by systemd-gpt-auto and there is
  # no resume= on the command line.
  swapDevices = [
    { device = "/dev/disk/by-uuid/92bea4ff-dcf7-4201-a376-37c10bc4c7dc"; }
  ];
  boot.resumeDevice = "/dev/disk/by-uuid/92bea4ff-dcf7-4201-a376-37c10bc4c7dc";

  # Long sleeps land in S4, where the *firmware* POSTs the GPU on the way back —
  # the path that always works on this board. 64 GB RAM, 34.4 GB swap, and a
  # default 25 GB image budget, so the image fits.
  systemd.sleep.settings.Sleep.HibernateDelaySec = "30min";
}
