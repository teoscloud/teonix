{ config, pkgs, stable-pkgs, unstable-pkgs, inputs, ... }:

let
  nwg-dock-scale-patch = pkgs.writeText "nwg-dock-scale-threshold.patch" ''
    diff --git a/main.go b/main.go
    --- a/main.go
    +++ b/main.go
    @@ -144,17 +144,11 @@ func rebuild(position *string) {
     		}
     	}
     
    -	divider := 1
    -	if len(allItems) > 0 {
    -		divider = len(allItems)
    -	}
    -
    -	// scale icons down when their number increases
    -	if *imgSize*6/(divider) < *imgSize {
    -		overflow := (len(allItems) - 6) / 3
    +	// scale icons down only past 30 apps, one step every 5 apps
    +	imgSizeScaled = *imgSize
    +	if len(allItems) > 30 {
    +		overflow := (len(allItems)-31)/5 + 1
     		imgSizeScaled = *imgSize * 6 / (6 + overflow)
    -	} else {
    -		imgSizeScaled = *imgSize
     	}
     
     	if *launcherPos == "start" {
  '';

  nwg-dock-scroll-patch = pkgs.writeText "nwg-dock-scroll-cycle.patch" ''
    diff --git a/tools.go b/tools.go
    --- a/tools.go
    +++ b/tools.go
    @@ -14,6 +14,9 @@ import (
     	"os"
     	"os/exec"
     	"path/filepath"
    +	"encoding/json"
    +	"sort"
    +	"time"
     	"strings"
     )
     
    @@ -27,6 +30,195 @@ func taskInstances(ID string) []client {
     	return found
     }
     
    +var lastInstanceCycleMs int64
    +
    +func absInt(x int) int {
    +	if x < 0 {
    +		return -x
    +	}
    +	return x
    +}
    +
    +// scroll up = +1 (next / higher workspace), scroll down = -1 (previous / lower workspace)
    +func scrollStepFromEvent(e *gdk.Event) int {
    +	scroll := e.AsScroll()
    +	if scroll == nil {
    +		return 0
    +	}
    +	switch scroll.Direction() {
    +	case gdk.ScrollUp:
    +		return 1
    +	case gdk.ScrollDown:
    +		return -1
    +	case gdk.ScrollSmooth:
    +		if scroll.DeltaY() < 0 {
    +			return 1
    +		}
    +		if scroll.DeltaY() > 0 {
    +			return -1
    +		}
    +	}
    +	return 0
    +}
    +
    +func addressesEqual(a, b string) bool {
    +	normalize := func(addr string) string {
    +		addr = strings.TrimSpace(strings.ToLower(addr))
    +		if addr == "" {
    +			return ""
    +		}
    +		if !strings.HasPrefix(addr, "0x") {
    +			addr = "0x" + addr
    +		}
    +		return addr
    +	}
    +	return normalize(a) == normalize(b)
    +}
    +
    +func sortedInstances(instances []client) []client {
    +	sorted := make([]client, len(instances))
    +	copy(sorted, instances)
    +	sort.Slice(sorted, func(i, j int) bool {
    +		if sorted[i].Workspace.Id != sorted[j].Workspace.Id {
    +			return sorted[i].Workspace.Id < sorted[j].Workspace.Id
    +		}
    +		return sorted[i].Address < sorted[j].Address
    +	})
    +	return sorted
    +}
    +
    +func instanceIndex(instances []client, address string) int {
    +	for i := range instances {
    +		if addressesEqual(instances[i].Address, address) {
    +			return i
    +		}
    +	}
    +	return -1
    +}
    +
    +func currentFocusedInstance(instances []client) *client {
    +	aw, err := getActiveWindow()
    +	if err == nil && aw != nil {
    +		for i := range instances {
    +			if addressesEqual(instances[i].Address, aw.Address) {
    +				return &instances[i]
    +			}
    +		}
    +	}
    +	if activeClient != nil {
    +		for i := range instances {
    +			if addressesEqual(instances[i].Address, activeClient.Address) {
    +				return &instances[i]
    +			}
    +		}
    +	}
    +	return nil
    +}
    +
    +func bestInstanceForCurrentWorkspace(instances []client) *client {
    +	sorted := sortedInstances(instances)
    +	if len(sorted) == 0 {
    +		return nil
    +	}
    +	aw, err := getActiveWindow()
    +	if err != nil || aw == nil {
    +		return &sorted[0]
    +	}
    +	currentWS := aw.Workspace.Id
    +	bestDist := int(^uint(0) >> 1)
    +	var onWS *client
    +	var closest *client
    +	for i := range sorted {
    +		inst := &sorted[i]
    +		if inst.Workspace.Id == currentWS && onWS == nil {
    +			onWS = inst
    +		}
    +		dist := absInt(inst.Workspace.Id - currentWS)
    +		if dist < bestDist {
    +			bestDist = dist
    +			closest = inst
    +		}
    +	}
    +	if onWS != nil {
    +		return onWS
    +	}
    +	return closest
    +}
    +
    +func scrollBaseInstance(instances []client) *client {
    +	if current := currentFocusedInstance(instances); current != nil {
    +		return current
    +	}
    +	return bestInstanceForCurrentWorkspace(instances)
    +}
    +
    +// Sorted by workspace (asc) then address; scroll up = next, scroll down = prev, wraps
    +func instanceByStep(instances []client, current *client, step int) *client {
    +	sorted := sortedInstances(instances)
    +	idx := instanceIndex(sorted, current.Address)
    +	if idx < 0 {
    +		return bestInstanceForCurrentWorkspace(instances)
    +	}
    +	n := len(sorted)
    +	next := (idx + step) % n
    +	if next < 0 {
    +		next += n
    +	}
    +	return &sorted[next]
    +}
    +
    +func getCursorNoWarps() int {
    +	reply, err := hyprctl("j/getoption cursor:no_warps")
    +	if err != nil {
    +		return 0
    +	}
    +	var opt struct {
    +		Int int `json:"int"`
    +	}
    +	if json.Unmarshal(reply, &opt) != nil {
    +		return 0
    +	}
    +	return opt.Int
    +}
    +
    +func focusClientFromScroll(c client) {
    +	prev := getCursorNoWarps()
    +	hyprctl("keyword cursor:no_warps true")
    +	focusClient(c)
    +	if prev == 0 {
    +		hyprctl("keyword cursor:no_warps false")
    +	} else {
    +		hyprctl(fmt.Sprintf("keyword cursor:no_warps %d", prev))
    +	}
    +}
    +
    +func handleInstanceScroll(class string, step int) bool {
    +	if step == 0 {
    +		return false
    +	}
    +	now := time.Now().UnixMilli()
    +	instances := taskInstances(class)
    +	if len(instances) <= 1 {
    +		return false
    +	}
    +	base := scrollBaseInstance(instances)
    +	if base == nil {
    +		return false
    +	}
    +	inst := instanceByStep(instances, base, step)
    +	if inst == nil {
    +		return false
    +	}
    +	// Small debounce to coalesce the burst of sub-events one physical notch emits,
    +	// while still letting deliberate consecutive scrolls each advance a step.
    +	if now-lastInstanceCycleMs < 50 {
    +		return true
    +	}
    +	focusClientFromScroll(*inst)
    +	lastInstanceCycleMs = now
    +	return true
    +}
    +
     func pinnedButton(ID string, position *string) *gtk.Box {
     	vertical = *position == "left" || *position == "right"
     
    @@ -290,6 +482,19 @@ func taskButton(t client, instances []client, position *string) *gtk.Box {
     			return false
     		})
     	}
    +
    +	if len(instances) > 1 {
    +		scrollMask := int(gdk.ScrollMask | gdk.SmoothScrollMask)
    +		scrollClass := t.Class
    +		button.AddEvents(scrollMask)
    +		box.AddEvents(scrollMask)
    +		button.Connect("scroll-event", func(_ *gtk.Button, e *gdk.Event) bool {
    +			return handleInstanceScroll(scrollClass, scrollStepFromEvent(e))
    +		})
    +		box.Connect("scroll-event", func(_ *gtk.Box, e *gdk.Event) bool {
    +			return handleInstanceScroll(scrollClass, scrollStepFromEvent(e))
    +		})
    +	}
     
     	return box
     }
  '';

  # Go dock force-rebuilds the full GTK tree (and reloads every icon pixbuf) on
  # every Hyprland activewindowv2 event. Destroy() does not promptly free those
  # pixbufs, so RSS climbs without bound during normal focus switching.
  # Only rebuild when the class multiset or active class actually changes.
  nwg-dock-smart-rebuild-patch = ./nwg-dock-smart-rebuild.patch;
  nwg-dock-hyprland = unstable-pkgs.nwg-dock-hyprland.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      nwg-dock-scale-patch
      nwg-dock-scroll-patch
      nwg-dock-smart-rebuild-patch
    ];
  });

  # nixpkgs 1.22.0 source build omits .desktop/icons; restore launcher integration.
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

  mailspring-with-launcher = unstable-pkgs.mailspring.overrideAttrs (old: {
    preFixup = (old.preFixup or "") + ''
      gappsWrapperArgs+=(--add-flags "--password-store=gnome-libsecret")
    '';
    postInstall = (old.postInstall or "") + ''
      mkdir -p $out/share/applications
      cp ${mailspringDesktop}/share/applications/mailspring.desktop $out/share/applications/

      for size in 16 32 64 128 256; do
        if [ -f app/build/resources/linux/icons/''${size}.png ]; then
          install -D -m 0644 app/build/resources/linux/icons/''${size}.png \
            $out/share/icons/hicolor/''${size}x''${size}/apps/mailspring.png
        fi
      done
    '';
  });

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
in {

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
    # Local override only (not a global overlay) — avoids cache-busting the whole qemu dep tree
    (qemu.override { cephSupport = false; })
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
    awww                 # Wallpaper management for sway and Hyprland
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
    carla
    yabridge
    yabridgectl

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
    ppsspp-sdl-wayland
    mailspring-with-launcher
    libsecret # Mailspring + other apps using org.freedesktop.Secrets (via gnome-keyring)

    exfatprogs
    

    ########################
    # Virtualization Tools #
    ########################
    virtiofsd
    
    udiskie

    looking-glass-client

    code-cursor
    nodejs
    

    pcsx2
    fastfetch
    onlyoffice-desktopeditors
    tradingview
    wtype
    shadps4
    texliveFull
    glow
    bottles               # Wine/Proton GUI (patool checks skipped — see let binding)

    #darktable  # Temporarily removed due to build issues with osm-gps-map dependency
    godot

    kitty

    lm_sensors

    #kdePackages.xwaylandvideobridge potentially needed
    whatsapp-electron

    vesktop
    discord-canary
    equibop

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

  ]) ++ [
    nwg-dock-hyprland
  ];
}
