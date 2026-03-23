
{ config, ... }:

{
  system.stateVersion = "24.05";  # Match your NixOS version

  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;
    loader.systemd-boot.configurationLimit = 10;

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

    extraModprobeConfig = ''
      options kvm_amd nested=1
      options kvm_amd emulate_invalid_guest_state=0
      options kvm ignore_msrs=1
    '';
  };
}
