{ config, ... }:

{

  #################################
  ## CPU & Power Management
  #################################
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "schedutil";

  #################################
  ## Kernel params for AMD APU
  #################################
  boot.kernelParams = [
    "amd_pstate=active"                # Use AMD's new frequency scaling driver (if supported)
    "amdgpu.dpm=1"                     # Enable dynamic power management for AMDGPU
    "amdgpu.dpm.forced=1"             # Force-enable DPM even on AC
    "amdgpu.ppfeaturemask=0xffffffff" # Unlock all DPM features
    "amdgpu.dc=1"                      # Display Core (usually already on, but we enforce it)
  ];

  #################################
  ## TLP – Power tuning
  #################################
  services.tlp.enable = true;
  services.tlp.settings = {
    # CPU governor on AC/BAT
    CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
    CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";

    # AMD-specific tuning
    CPU_ENERGY_PERF_POLICY_ON_AC = "balance_performance";
    CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

    # Platform profiles (if supported)
    PLATFORM_PROFILE_ON_AC = "balanced";
    PLATFORM_PROFILE_ON_BAT = "low-power";

    # Optional: tweak GPU
    RADEON_DPM_PERF_LEVEL_ON_AC = "auto";
    RADEON_DPM_PERF_LEVEL_ON_BAT = "low";

  };

  #################################
  ## Power Profiles Daemon (for switching profiles)
  #################################
  services.power-profiles-daemon.enable = true;

}
