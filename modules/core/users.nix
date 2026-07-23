{ config, pkgs, stable-pkgs, username, ... }:

{
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "networkmanager" "wheel" "docker" "libvirtd" "input" "kvm" "storage" ];
    
    packages = with pkgs; [
      # Add unstable packages here
    ] ++ (with stable-pkgs; [
      # Add stable packages here
    ]);
  };
}
