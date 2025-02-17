{ config, ... }:

{

  #powerManagement.enable = true;
  #powerManagement.cpuFreqGovernor = "powersave";

  #services.system76-scheduler.enable = true;

  #services.power-profiles-daemon.enable = true;

  services.auto-cpufreq.enable = true;
  services.auto-cpufreq.settings = {
    battery = {
      governor = "powersave";
      turbo = "never";
    };
    charger = {
      governor = "balanced";
      turbo = "auto";
    };
  };

}
