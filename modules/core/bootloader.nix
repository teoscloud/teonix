
{ config, ... }:

{
  system.stateVersion = "24.05";  # Match your NixOS version

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # early kms
    initrd.kernelModules = [ 
      "vfio_pci"
      "vfio"
      "vfio_iommu_type1"
      #"amdgpu"

      #"nouveau"
      #"nvidia"
      #"nvidia_modeset"
      #"nvidia_uvm"
      #"nvidia_drm" 
    ];
  };
}
