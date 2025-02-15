{ config, pkgs, username, ... }:

{
  virtualisation = {
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    docker = {
      enable = true;

      rootless = {
        enable = true;
        setSocketVariable = true;
      };
    };

    # libvirt
    spiceUSBRedirection.enable = true;
    libvirtd = {
      enable = true;
      qemu = {
        swtpm.enable = true;
        ovmf.enable = true;
        ovmf.packages = [pkgs.OVMFFull.fd];
      };
    };

    # android
    waydroid.enable = true;

    vmware.host.enable = true;

  };

  services.udev.extraRules = ''
    # Set permissions for evdev devices to allow read/write for all users
    KERNEL=="event*", SUBSYSTEM=="input", GROUP="input", MODE="0666"
  '';

  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 ${username} qemu-libvirtd -"
  ];

}