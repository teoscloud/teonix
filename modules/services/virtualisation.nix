{ config, pkgs, lib, system ? "x86_64-linux", username, hostname ? "", ... }:

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
        # Big-disk docker data on nixbox / mainframe; other hosts keep the default.
        daemon.settings = lib.mkIf (hostname == "nixbox" || hostname == "mainframe") {
          data-root = "/home/teodor/mnt/qvo870/dockerdata";
          features.buildkit = true;
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

  # Cap rootless Docker so the host doesn't starve (nixbox 32G vs Xeon workstation).
  systemd.user.services.docker.serviceConfig.MemoryMax =
    if hostname == "mainframe" then "48G" else "16G";
  systemd.user.services.docker.serviceConfig.MemoryHigh =
    if hostname == "mainframe" then "40G" else "14G";

  services.udev.extraRules = ''
    # Set permissions for evdev devices to allow read/write for all users
    KERNEL=="event*", SUBSYSTEM=="input", GROUP="input", MODE="0666"
  '';

  systemd.tmpfiles.rules = lib.optionals (system == "x86_64-linux") [
    "f /dev/shm/looking-glass 0660 ${username} qemu-libvirtd -"
  ];

}