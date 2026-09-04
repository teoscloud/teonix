# Shared GUI/CLI package list for NixOS systemPackages and Fedora home.packages.
# Filter drops anything that cannot evaluate on the current host platform
# (Steam/Wine-adjacent bits vanish on aarch64).
{ unstable-pkgs, stable-pkgs, lib }:

let
  # Wrap cached mailspring — do NOT overrideAttrs (that rebuilds the Electron app).
  mailspringDesktop = unstable-pkgs.makeDesktopItem {
    name = "mailspring";
    desktopName = "Mailspring";
    genericName = "Mail Client";
    comment = "The best email app for people and teams at work";
    exec = "mailspring %U";
    icon = "mailspring";
    categories = [ "Network" "Email" "Office" ];
    mimeTypes = [ "x-scheme-handler/mailto" "x-scheme-handler/mailspring" ];
    startupWMClass = "Mailspring";
  };

  mailspring-with-launcher = unstable-pkgs.symlinkJoin {
    name = "mailspring-with-launcher";
    paths = [ unstable-pkgs.mailspring mailspringDesktop ];
    nativeBuildInputs = [ unstable-pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram "$out/bin/mailspring" \
        --add-flags "--password-store=gnome-libsecret"
    '';
  };

  # Chromium-family apps probe XDG_CURRENT_DESKTOP and pick KWallet after a
  # Plasma login. Force gnome-libsecret so they follow gnome-keyring in every DE.
  withGnomeLibsecret = pkg:
    unstable-pkgs.symlinkJoin {
      name = "${pkg.pname or pkg.name}-libsecret";
      paths = [ pkg ];
      nativeBuildInputs = [ unstable-pkgs.makeWrapper ];
      meta = pkg.meta or { };
      postBuild = ''
        for b in "$out/bin/"*; do
          [ -x "$b" ] && [ ! -d "$b" ] || continue
          wrapProgram "$b" --add-flags "--password-store=gnome-libsecret"
        done
      '';
    };

  hyprflow = import ./hyprflow.nix {
    lib = unstable-pkgs.lib;
    rustPlatform = unstable-pkgs.rustPlatform;
    fetchFromGitHub = unstable-pkgs.fetchFromGitHub;
  };

  # Bottles → patool: not on cache for python3.14 yet, and patool's test suite
  # fails in the sandbox (MIME/bzip2). Skip checks only inside an extended
  # package set used for bottles — does not rebuild the rest of the system.
  bottles = (unstable-pkgs.extend (final: prev: {
    python3Packages = prev.python3Packages.overrideScope (_pyfinal: pyprev: {
      patool = pyprev.patool.overrideAttrs (_old: {
        doCheck = false;
        doInstallCheck = false;
      });
    });
  })).bottles;

  # scheme-full depends on Asymptote → PyQt5. PyQt5 cannot target Python 3.14
  # ABI v12, so keep TeX Live 2025 and drop only asy/xasy.
  texliveFull = unstable-pkgs.texlive.combine {
    inherit (unstable-pkgs.texlive) scheme-full;
    extraName = "full-no-asymptote";
    pkgFilter = pkg:
      pkg.pname != "asymptote"
      && (
        pkg.tlType == "run"
        || pkg.tlType == "bin"
        || pkg.pname == "core"
        || pkg.hasManpages or false
      );
  };
in

lib.filter (pkg: lib.meta.availableOn unstable-pkgs.stdenv.hostPlatform pkg) (
  with unstable-pkgs; [
    home-manager

    ####################
    # System Utilities #
    ####################
    wev
    hyprflow
    zsh
    git
    pciutils
    ffmpeg
    socat
    bat
    ripgrep
    lshw
    pkg-config
    meson
    ninja

    libva
    vulkan-loader
    vulkan-tools

    #######################
    # Development Tools   #
    #######################
    appimage-run
    yad
    playerctl
    docker-compose
    docker

    #######################
    # Monitoring & Power  #
    #######################
    powertop
    lm_sensors
    btop
    inxi
    pavucontrol

    ###################
    # Theming & Fonts #
    ###################
    apple-cursor
    whitesur-gtk-theme

    pywal
    material-icons

    ##################
    # Wayland Tools  #
    ##################
    wl-clipboard
    swaynotificationcenter
    grim
    slurp

    quickshell
    libqalculate
    gnome-calculator
    waybar
    wofi
    wofi-emoji
    sway
    swaybg
    snapshot

    ################
    # Gaming Tools #
    vkbasalt
    ################
    baobab

    ####################
    # Media & Graphics #
    ####################
    mpv
    imv
    spotify
    spotify-tray
    protontricks
    mangohud
    rustc
    cargo

    ####################
    # Miscellaneous    #
    ####################
    stress

    winetricks

    (python3.withPackages (ps: [
      ps.requests
      ps.tkinter
    ]))

    free42
    prismlauncher
    mediawriter
    piper
    brightnessctl
    tree
    neovide
    unrar
    htop
    killall
    eza
    cmatrix
    unzip
    ncdu
    jq
    duf
    swappy
    mousam
    lolcat

    pulseaudioFull

    wireplumber
    wget
    blueman
    wgnord
    vscodium
    gnome-tweaks
    gnome-software

    fastfetch
    gammastep
    networkmanagerapplet
    nemo
    signal-desktop
    scli
    pfetch
    pear-desktop
    obsidian
    (qemu.override { cephSupport = false; })
    libvirt
    virt-manager
    virt-viewer
    bridge-utils
    dnsmasq
    clipman
    cowsay
    nixfmt
    tuigreet
    lxqt.lxqt-policykit
    libnotify
    v4l-utils
    ydotool
    rofi
    wlogout
    nwg-look
    distrobox
    firefox-esr
    protonup-ng

    fuse3
    zip
    awww
    themechanger
    polkit_gnome
    p7zip
    file

    libgcc
    vcpkg
    gnumake
    cmakeMinimal
    scrcpy

    libglvnd
    nix-ld
    samba

    yt-dlp
    nix-index

    qbittorrent

    ghex
    obs-studio
    obs-studio-plugins.obs-pipewire-audio-capture

    dconf
    hyprpaper
    hyprpicker

    (withGnomeLibsecret unstable-pkgs.brave)
    (withGnomeLibsecret unstable-pkgs.chromium)
    (withGnomeLibsecret unstable-pkgs.google-chrome)

    haskellPackages.asana
    geary
    ppsspp-sdl-wayland
    mailspring-with-launcher
    libsecret

    exfatprogs

    virtiofsd

    udiskie

    code-cursor
    nodejs

    onlyoffice-desktopeditors
    tradingview
    wtype
    glow
    bottles

    godot

    kitty

    whatsapp-electron

    vesktop
    discord-canary
    equibop
    eden

  ] ++ (with stable-pkgs; [
    cava
    whitesur-icon-theme
    gnome-extension-manager
    heroic

    arrpc

    qmmp
    clementine

    chiaki-ng

    # Unstable Carla pulls PyQt5 against Python 3.14 (ABI v12) and fails to
    # build. 24.05's 2.5.8 is cached and still uses 3.11.
    carla

  ]) ++ [
    texliveFull
  ]
)
