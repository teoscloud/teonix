let
  # GTX 1060 3G
  gpuIDs = [
    "10de:1c02" # Graphics
    "10de:10f1" # Audio
  ];
in { pkgs, lib, config, ... }: {
  options.vfio.enable = with lib;
    mkEnableOption "Configure the machine for VFIO";

  config = let cfg = config.vfio;
  in {
    boot = {

      blacklistedKernelModules = [ "nouveau" ];

      kernelParams = [
        # enable IOMMU
        "amd_iommu=on"
      ] ++ lib.optional cfg.enable
        # isolate the GPU
        ("vfio-pci.ids=" + lib.concatStringsSep "," gpuIDs);
    };

    #hardware.opengl.enable = true;
    #virtualisation.spiceUSBRedirection.enable = true;
  };
}