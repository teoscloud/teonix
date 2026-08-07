{ config, pkgs, username, hostname ? "", lib, ... }:

{
  virtualisation = {
    podman = {
      enable = true;
      defaultNetwork.settings.dns_enabled = true;
    };

    # WordPress / HTTP on LAN: publish "8080:80" as "0.0.0.0:8080:80" (all interfaces), not 127.0.0.1.
    # Host firewall: TCP 8080 is in modules/services/networking.nix — rebuild & switch to apply.
    docker = {
      enable = true;

      rootless = {
        enable = true;
        setSocketVariable = true;
        # Desktop docker data lives on the big disk; other hosts keep the default.
        daemon.settings = lib.mkIf (hostname == "nixbox") {
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

  # Cap Docker (rootless user service) to 16GB so the host doesn't starve
  systemd.user.services.docker.serviceConfig.MemoryMax = "16G";
  systemd.user.services.docker.serviceConfig.MemoryHigh = "14G";

  services.udev.extraRules = ''
    # Set permissions for evdev devices to allow read/write for all users
    KERNEL=="event*", SUBSYSTEM=="input", GROUP="input", MODE="0666"
  '';

  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 ${username} qemu-libvirtd -"
  ];

}