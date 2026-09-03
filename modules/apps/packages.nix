{ config, pkgs, stable-pkgs, unstable-pkgs, inputs, lib, ... }:

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
in {

  nixpkgs.config.permittedInsecurePackages = [
    "dotnet-runtime-wrapped-6.0.36"
  ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = lib.filter (pkg: lib.meta.availableOn unstable-pkgs.stdenv.hostPlatform pkg) (
    with unstable-pkgs; [
    home-manager

    ####################
    # System Utilities #
    ####################
    wev
    hyprflow             # Save/restore Hyprland window sessions across reboots
    zsh                 # Shell
    git                 # Version control
    pciutils            # PCI device listing utilities
    ffmpeg              # Multimedia framework
    socat               # Multipurpose relay
    bat                 # Cat command replacement
    ripgrep             # Line-oriented search tool
    lshw                # Hardware listing
    pkg-config          # Tool to configure compiler and linker flags
    meson               # Build system
    ninja               # Build system
    #xwayland
    

    libva
    vulkan-loader
    vulkan-tools           # vulkaninfo — verify driver visibility
    

    #######################
    # Development Tools   #
    #######################
    appimage-run         # Run AppImages
    yad                  # Dialog boxes from shell scripts
    playerctl            # Media player control
    docker-compose       # Docker utility
    docker               # Docker itself

    #######################
    # Monitoring & Power  #
    #######################
    powertop             # Power consumption tool
    lm_sensors           # Hardware monitoring
    btop                 # Resource monitoring tool
    inxi                 # System information script
    pavucontrol          # PulseAudio volume control

    

    ###################
    # Theming & Fonts #
    ###################
    apple-cursor         # Mac-like cursor
    whitesur-gtk-theme   # GTK theme
    
    pywal                # Color scheme generator
    material-icons       # Material design icons

    ##################
    # Wayland Tools  #
    ##################
    wl-clipboard         # Wayland clipboard tool
    swaynotificationcenter # Notification center for sway
    grim                 # Screenshot tool for Wayland
    slurp                # Select a region for screenshots in Wayland
    
    quickshell           # QML Wayland shell (nixbox primary bar/dock/notifs)
    libqalculate         # qalc CLI for Quickshell Spotlight math
    gnome-calculator     # Spotlight "Open Calculator" action
    waybar               # Status bar for Wayland (legacy / other hosts)
    wofi                 # Application launcher for Wayland
    wofi-emoji           # Emoji picker for Wayland
    sway                 # Wayland compositor
    swaybg               # Background utility for sway
    snapshot

    ################
    # Gaming Tools #
    vkbasalt              # Vulkan post-processing layer for vibrance/saturation
    ################
    baobab
    
    ####################
    # Media & Graphics #
    ####################
    mpv                 # Media player
    imv                 # Image viewer
    spotify             # Spotify client
    spotify-tray        # Tray control for Spotify
    protontricks        # Tools for Proton gaming
    mangohud            # Gaming performance overlay
    rustc
    cargo

    ####################
    # Miscellaneous    #
    ####################
    
    stress              # CPU stress testing tool
    
    winetricks           # Wine helper tool

    (python3.withPackages (ps: [
      ps.requests
      ps.tkinter
    ]))

    free42              # Calculator app
    prismlauncher       # Minecraft launcher
    mediawriter         # Fedora Media Writer
    piper               # Configure gaming mice
    #customRetroarch     # Fixed RetroArch override
    # retroarch-full pulls libretro-fbalpha2012, which fails to build on recent nixpkgs (gcc/glibc); same as full minus that core
    (
      retroarch.withCores (
        cores:
        lib.filter (
          c:
          (c ? libretroCore)
          && (lib.meta.availableOn stdenv.hostPlatform c)
          && (!lib.strings.hasInfix "fbalpha2012" c.name)
        ) (lib.attrValues cores)
      )
    )
    brightnessctl       # Adjust screen brightness
    tree                # Directory tree visualization
    neovide             # Neovim GUI client
    unrar               # Unrar utility
    htop                # Interactive process viewer
    killall             # Kill processes
    eza                 # Modern replacement for `ls`
    cmatrix             # Matrix effect in the terminal
    unzip               # Unzip utility
    ncdu                # Disk usage analyzer
    jq                  # JSON processor
    duf                 # Disk usage utility
    swappy              # Screenshot annotation tool
    mousam              # Mouse control app
    lolcat              # Rainbow coloring for terminal output
   
   #(wineWowPackages.full.override {
   #   wineRelease = "staging";
   #   mingwSupport = true;
   # })

    #python311
    #python311Packages.requests

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
    # Local override only (not a global overlay) — avoids cache-busting the whole qemu dep tree
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
    awww                 # Wallpaper management for sway and Hyprland
    themechanger
    polkit_gnome
    p7zip
    file

    # build tools
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
    hyprpaper            # Wallpaper tool
    hyprpicker           # Color picker
    #hypridle             # Idle management for Hyprland
    #hyprlock             # Lock screen tool for Hyprland
    #xwayland
    
    brave
    chromium
    google-chrome

    #lutris               # Gaming platform for Linux
    
    haskellPackages.asana
    geary
    ppsspp-sdl-wayland
    mailspring-with-launcher
    libsecret # Mailspring + other apps using org.freedesktop.Secrets (via gnome-keyring)

    exfatprogs
    

    ########################
    # Virtualization Tools #
    ########################
    virtiofsd
    
    udiskie

    code-cursor
    nodejs
    

    onlyoffice-desktopeditors
    tradingview
    wtype
    glow
    bottles               # Wine/Proton GUI (patool checks skipped — see let binding)

    #darktable  # Temporarily removed due to build issues with osm-gps-map dependency
    godot

    kitty


    #kdePackages.xwaylandvideobridge potentially needed
    whatsapp-electron

    vesktop
    discord-canary
    equibop
    eden

  ] ++ (with stable-pkgs; [
    # potential stable:

    cava
    whitesur-icon-theme  # Icon theme
    jetbrains.idea-ultimate
    gnome-extension-manager
    heroic              # Game launcher

    arrpc
    
    
    qmmp
    clementine

    chiaki-ng

    # Unstable Carla pulls PyQt5 against Python 3.14 (ABI v12) and fails to
    # build. 24.05's 2.5.8 is cached and still uses 3.11.
    carla

  ]) ++ [
    texliveFull
  ]);
}
