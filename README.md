# 🌟 Teonix - A Modular NixOS & Home Manager Configuration

> 🚀 Your personal NixOS configuration, supercharged with customization and portability!

Teonix is a modular and customized NixOS configuration designed for seamless portability between different machines while keeping a consistent user experience. 

## 🎯 Features

- 🔧 Pre-configured system with sensible defaults
- 🏠 Integrated Home Manager setup
- 🎨 Custom dotfiles (Hyprland, Kitty, Waybar, etc.)
- 📦 Curated package selection
- 💻 Host-specific configurations (Desktop/Laptop)
- 🔄 Easy synchronization between machines
- 🛠️ Convenient shell aliases and scripts

## 🚀 Quick Start

### 📥 1. Clone the Repository

Before installing Teonix, you must clone the repository into your home directory to ensure the shell aliases and scripts function properly:

```bash
cd ~
git clone https://github.com/teoscloud/teonix.git
cd teonix
```

This will create a `~/teonix` directory, which will be used by Home Manager and system scripts.

### ⚙️ 2. Choose Your Installation Type

#### 🎲 Default Setup (General Use)

The default installation provides the full Teonix experience, including:

✨ Customized dotfiles (Hyprland, Kitty, Waybar, etc.)  
🔧 Pre-configured system settings  
🏠 Home Manager for user configuration  
🎮 No GPU passthrough or EDID patches required  

```bash
# 1. Ensure NixOS is installed
# 2. Generate hardware config (if missing):
sudo nixos-generate-config

# 3. Apply Teonix configuration:
sudo nixos-rebuild switch --flake "path:."#$HOST
home-manager switch --flake "path:."#$HOST
```

#### 🖥️ Desktop Setup (Nixbox)

Perfect for desktop workstations with:

🎮 GPU Passthrough support (VFIO)  
🖥️ Custom EDID patches for monitor support  
🎯 Performance-focused configuration  

```bash
# 1. Install EDID firmware first!
cd ~/teonix/scripts
sudo ./edidinstall.sh

# 2. Apply configuration:
sudo nixos-rebuild switch --flake "path:."#nixbox --impure
home-manager switch --flake "path:."#nixbox
```

#### 💻 Laptop Setup (Nixtop)

Optimized for portable devices with:

🔋 Power management optimization  
💡 Brightness controls  
📱 Touchpad gestures  
🎮 No GPU passthrough needed  

```bash
sudo nixos-rebuild switch --flake "path:."#nixtop
home-manager switch --flake "path:."#nixtop
```

## 🎨 Customization

### 🎯 Installing iOS Emojis

Get the Apple emoji experience:

```bash
cd ~/teonix/scripts
./iosemojis.sh
```

### ⌨️ Shell Aliases

Teonix comes with powerful zsh aliases for system management:

- 🔄 `systemupdate`: Full system update
- 🏠 `updatehome`: Update Home Manager only
- ⬆️ `nixupgrade`: Update NixOS without flake.lock
- 📦 `nixupdate`: Update flake dependencies

## 🔄 Syncing Between Machines

### 📤 Push Changes

```bash
git add .
git commit -m "✨ Updated Teonix configuration"
git push
```

### 📥 Pull Changes

```bash
cd ~/teonix
git pull
systemupdate
```

## 🎯 Requirements

- 📦 NixOS installed
- 🏠 Home Manager
- ⚡ Git
- 🔑 Basic Nix knowledge

## 🚨 Important Notes

- 📂 Always clone in `~` for proper alias functionality (might get fixed in the future)
- 🖥️ Custom EDID users: Don't forget `--impure` flag
- 🔧 Default install: Perfect for general use
- 📚 Configs are modular (per host)

## 🤝 Contributing

Feel free to:
- 🐛 Report bugs
- 💡 Suggest features
- 🔧 Submit PRs
- 🌟 Star the repo if you like it!

## 📝 License

MIT License - Feel free to use and modify! 🎉

---
Made with 💝 by the Teo
