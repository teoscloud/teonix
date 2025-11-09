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
        # For rootless Docker, daemon settings must be under rootless.daemon.settings
        daemon.settings = {
          data-root = "/home/teodor/mnt/qvo870/dockerdata";
        };
      };
    };

    # libvirt
    spiceUSBRedirection.enable = true;
    libvirtd = {
      enable = true;
      onBoot = "start";
      onShutdown = "shutdown";

      qemu = {
        swtpm.enable = true;
      };

    };

    # android
    waydroid.enable = true;

    #vmware.host.enable = true;

  };

  services.udev.extraRules = ''
    # Set permissions for evdev devices to allow read/write for all users
    KERNEL=="event*", SUBSYSTEM=="input", GROUP="input", MODE="0666"
  '';

  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 ${username} qemu-libvirtd -"
  ];

}