{ config, pkgs, ... }:

{

  hardware = {

    # Miscellaneous configurations

    bluetooth.enable = true;

    # Bluetooth settings
    bluetooth.settings = {
      General = {
        Enable = "Source,Sink,Media,Socket";
        Experimental = true;
      };
    };

    # Graphics settings — AMD RADV (Mesa) is the primary Vulkan driver
    graphics = {
      enable = true;
      enable32Bit = true;

      extraPackages = with pkgs; [
        # Vulkan runtime (RADV is inside Mesa; loader + validation make it discoverable)
        vulkan-loader
        vulkan-validation-layers

        # ROCm/OpenCL compute (not Vulkan, but needed for GPU compute workloads)
        rocmPackages.clr.icd
        rocmPackages.rocm-runtime
        rocmPackages.rocminfo
      ];

      # 32-bit Vulkan/RADV: handled by enable32Bit = true (pulls in 32-bit Mesa + loader)
    };

  };

  
}
