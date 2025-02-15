{ config, pkgs, stable-pkgs, username, ... }:

{
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirt" "nordvpn" "input" ];
    
    packages = with pkgs; [
      # Add unstable packages here
    ] ++ (with stable-pkgs; [
      # Add stable packages here
    ]);
  };
}
