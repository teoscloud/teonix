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
    nixfmt-rfc-style     # Nix code formatting
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

    ################
    # Gaming Tools #
    ################
    #bottles              # Wine and Proton GUI
    protonup             # Proton updater
    
    dolphin-emu          # GameCube/Wii emulator
    
    ####################
    # Media & Graphics #
    ####################
    mpv                 # Media player
    gimp                # Image editing
    imv                 # Image viewer
    spotify             # Spotify client
    spotify-tray        # Tray control for Spotify
    moonlight-qt        # Game streaming client
    protontricks        # Tools for Proton gaming
    mangohud            # Gaming performance overlay

    ####################
    # Miscellaneous    #
    ####################
    
        stress              # CPU stress testing tool
    moonlight-qt        # Game streaming client
    
    winetricks           # Wine helper tool
    inputs.nix-gaming.packages.${pkgs.system}.wine-tkg # installs a package
    # support both 32- and 64-bit applications
    #wineWowPackages.stable

    # support 32-bit only
    #wine

    # support 64-bit only
    #(wine.override { wineBuild = "wine64"; })

    # support 64-bit only
    #wine64

    # wine-staging (version with experimental features)
    #wineWowPackages.staging

    # winetricks (all versions)

    # native wayland support (unstable)
    #wineWowPackages.waylandFull

    (python3.withPackages (subpkgs: with subpkgs; [
        requests
    ]))

    free42              # Calculator app
    mangohud            # Gaming performance overlay
    prismlauncher       # Minecraft launcher
    mediawriter         # Fedora Media Writer
    piper               # Configure gaming mice
    #customRetroarch     # Fixed RetroArch override
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
    
    neofetch
    kitty
    gammastep
    gimp
    networkmanagerapplet
    nemo
    signal-desktop
    scli
    pfetch
    youtube-music
    obsidian
    amdgpu_top
    qemu
    libvirt
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
    nixfmt-rfc-style
    swww
    grim
    slurp
    swaynotificationcenter
    imv
    mpv
    pavucontrol
    tree
    neovide
    greetd.tuigreet
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
    protonup
    
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
    stremio
    libsForQt5.qtstyleplugin-kvantum
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
    qmmp
    clementine
    yt-dlp
    nix-index
    rpcs3
    qbittorrent
    easyeffects
    microsoft-edge
    
    ghex
    obs-studio 

    dconf
    hyprpaper            # Wallpaper tool
    hyprpicker           # Color picker
    #hypridle             # Idle management for Hyprland
    #hyprlock             # Lock screen tool for Hyprland
    #xwayland
    xwaylandvideobridge
    
    brave
    chromium
    google-chrome

    lutris               # Gaming platform for Linux
    
    
    

    ########################
    # Virtualization Tools #
    ########################
    qemu                 # Virtualization tool
    libvirt              # Virtualization management
    virt-manager         # Virtual machine manager
    virt-viewer          # Virtual machine viewer
    bridge-utils         # Network bridge utilities
    dnsmasq              # DNS forwarding and DHCP services
    virtiofsd
    
    #gnome-desktop
    whatsapp-for-linux

    looking-glass-client
    

    #discord-screenaudio
    #discord-krisp

    
  ] ++ (with stable-pkgs; [

    cava
    whitesur-icon-theme  # Icon theme

    bottles
    jetbrains.idea-ultimate
    
    gnome-extension-manager
    
    heroic              # Game launcher


    vesktop
    

    #space-cadet-pinball # Classic pinball game
    
    #python3.withPackages (ps: with ps; [ requests ]) # Python 3.10 with requests package
  ]);
}
