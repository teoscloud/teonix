{ config, pkgs, unstable-pkgs, stable-pkgs, lib, ... }:

{
  environment.systemPackages = with unstable-pkgs; [
    wowup-cf
    xivlauncher
    corectrl
    amdgpu_top
    OVMF
    moonlight-qt
    yabridge
    yabridgectl
    davinci-resolve
    looking-glass-client
    pcsx2
    shadps4
    dolphin-emu
    steam-run
    steam-devices-udev-rules
  ];
}
