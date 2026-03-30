{ config, pkgs, stable-pkgs, unstable-pkgs, inputs, ... }:

#let
#  pythonPackages = pkgsUnstable.python3Packages;
#in



{

  nixpkgs.config.permittedInsecurePackages = [
    "dotnet-runtime-wrapped-6.0.36"
  ];

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with unstable-pkgs; [
    home-manager

    ####################
    # System Utilities #
    ####################
    wev
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
    
    waybar               # Status bar for Wayland
    wofi                 # Application launcher for Wayland
    wofi-emoji           # Emoji picker for Wayland
    sway                 # Wayland compositor
    swaybg               # Background utility for sway
    snapshot

    ################
    # Gaming Tools #
    vkbasalt              # Vulkan post-processing layer for vibrance/saturation
    ################
    #bottles              # Wine and Proton GUI
    
    dolphin-emu          # GameCube/Wii emulator
    wowup-cf
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
    mangohud            # Gaming performance overlay
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
    xivlauncher
    wl-clipboard         # Wayland clipboard tools
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
    corectrl
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
    amdgpu_top
    qemu                  # Using qemu instead of qemu_full to avoid broken Python dependencies
    libvirt
    OVMF
    virt-manager
    virt-viewer
    steam-devices-udev-rules
    bridge-utils
    dnsmasq
    powertop
    docker-compose
    zsh
    apple-cursor
    wl-clipboard
    clipman
    pciutils
    ffmpeg
    socat
    cowsay
    ripgrep
    lshw
    bat
    pkg-config
    meson
    brightnessctl
    swappy
    appimage-run
    yad
    inxi
    playerctl
    pkgs.nixfmt
    swww
    grim
    slurp
    swaynotificationcenter
    imv
    mpv
    pavucontrol
    tree
    neovide
    tuigreet
    killall
    eza
    cmatrix
    lolcat
    htop
    lxqt.lxqt-policykit
    lm_sensors
    unzip
    unrar
    libnotify
    v4l-utils
    ydotool
    duf
    ncdu
    jq
    spotify
    spotify-tray
    wofi
    rofi
    wofi-emoji
    waybar
    wlogout
    nwg-look
    pywal
    material-icons
    distrobox
    firefox-esr
    stress
    btop
    piper
    whitesur-gtk-theme
    mangohud
    protonup-ng
    
    protontricks
    prismlauncher
    mediawriter
    free42
    moonlight-qt
    mousam
    dolphin-emu
    fuse3
    zip
    swww                 # Wallpaper management for sway and Hyprland
    themechanger
    polkit_gnome
    p7zip
    file

    # build tools
    ninja
    libgcc
    vcpkg
    gnumake
    cmakeMinimal
    scrcpy


    libglvnd
    steam-run
    nix-ld
    samba
    
    yt-dlp
    nix-index
    
    qbittorrent
    easyeffects
    
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
    davinci-resolve
    
    haskellPackages.asana
    geary

    exfatprogs
    

    ########################
    # Virtualization Tools #
    ########################
    virtiofsd
    
    udiskie

    looking-glass-client
    
    kdePackages.kwalletmanager

    code-cursor
    nodePackages.nodejs
    

    rpcs3
    pcsx2
    fastfetch
    onlyoffice-desktopeditors
    tradingview
    wtype
    shadps4
    texliveFull
    glow
    bottles

    #darktable  # Temporarily removed due to build issues with osm-gps-map dependency
    godot

    kitty

    lm_sensors

    #kdePackages.xwaylandvideobridge potentially needed
    whatsapp-electron

    vesktop
    

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

  ]);
}
