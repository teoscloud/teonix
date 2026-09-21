{ config, lib, hostname ? "", ... }:

{
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    # 511 MiB ESP on mainframe; initrds run 50-85 MiB each (GPU firmware), so 10
    # entries overflowed it on 2026-09-21 ("No space left on device" mid-switch).
    loader.systemd-boot.configurationLimit = 5;

    initrd.kernelModules = [
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"
    ];

    extraModprobeConfig = lib.mkIf (hostname != "mainframe") ''
      options kvm_amd nested=1
      options kvm_amd emulate_invalid_guest_state=0
      options kvm ignore_msrs=1
    '';
  };
}
