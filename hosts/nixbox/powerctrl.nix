{ config, pkgs, lib, ... }:
{
  # Make sure PPD is OFF
  services.power-profiles-daemon.enable = false;

  # CPU scaling (Ryzen)
  powerManagement.enable = true;
  powerManagement.cpuFreqGovernor = "schedutil";
  boot.kernelParams = [ "amd_pstate=active" ];   # use "passive" if needed
  boot.kernelModules = [ "k10temp" "nct6775" ];

  # Quiet defaults with easy boost control
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "schedutil";
      CPU_BOOST_ON_AC = 0;   # turn off turbo for silence; flip to 1 when you need performance
    };
  };

}
