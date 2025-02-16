# Teonix - A Modular NixOS & Home Manager Configuration

Teonix is a modular and customized NixOS configuration designed for seamless portability between different machines while keeping a consistent user experience.

This configuration includes dotfiles, packages, Hyprland settings, and system configurations, providing a custom NixOS experience out-of-the-box.

## ✨ Installation Guide

### 1. Clone the Repository

Before installing Teonix, you must clone the repository into your home directory to ensure the shell aliases and scripts function properly:

```bash
cd ~
git clone https://github.com/teoscloud/teonix.git
cd teonix
```

This will create a `~/teonix` directory, which will be used by Home Manager and system scripts.

### 2. Installing Teonix (Default Setup)

The default installation provides the full Teonix experience, including:

✓ Customized dotfiles (Hyprland, Kitty, Waybar, etc.)  
✓ Pre-configured system settings  
✓ Home Manager for user configuration  
✓ No GPU passthrough or EDID patches required  

#### Installation Steps

1. Ensure you have NixOS installed. If not, install NixOS first.
2. Generate a hardware configuration (if missing):
   ```bash
   sudo nixos-generate-config
   ```
3. Apply Teonix default configuration:
   ```bash
   sudo nixos-rebuild switch --flake "path:."#default
   home-manager switch --flake "path:."#teodor
   ```

### 3. Installing Teonix on Nixbox (Desktop)

The Nixbox configuration includes everything from default but also:

✓ Custom EDID patch for monitor support  
✓ GPU Passthrough configuration (VFIO)  
✓ Requires an additional EDID setup step  

⚠️ Important: Run `edidinstall.sh` First!

Before applying nixbox, you must install the custom EDID firmware for proper monitor detection:

```bash
cd ~/teonix/scripts
sudo ./edidinstall.sh
```

#### Installation Steps

1. Clone the repo into `~/teonix`
2. Run the EDID install script (`edidinstall.sh`)
3. Apply the Nixbox configuration:
   ```bash
   sudo nixos-rebuild switch --flake "path:."#nixbox --impure
   home-manager switch --flake "path:."#pc
   ```

The `--impure` flag is needed for Nixbox because the custom EDID file is stored outside of the Nix store.

### 4. Installing Teonix on Nixtop (Laptop)

The Nixtop configuration includes:

✓ Custom dotfiles for a seamless UX  
✓ No GPU passthrough or EDID patches  
✓ Tailored for laptop use  

#### Installation Steps

1. Clone the repo into `~/teonix`
2. Apply the Nixtop configuration:
   ```bash
   sudo nixos-rebuild switch --flake "path:."#nixtop
   home-manager switch --flake "path:."#laptop
   ```

Unlike nixbox, Nixtop does not require `--impure` since there are no out-of-store dependencies.

## Additional Features

### 5. Installing iOS Emojis

Teonix allows you to use Apple iOS emojis by running:

```bash
cd ~/teonix/scripts
./iosemojis.sh
```

This will install Apple-style emojis for a better UI experience.

### 6. Shell Aliases (zshaliases.sh)

Teonix includes useful Zsh aliases for easy updates. These are stored in `~/.zshaliases.sh` and loaded into Zsh automatically.

#### Available Commands

- Update system (includes Home Manager & flake update):
  ```bash
  systemupdate
  ```
- Update only Home Manager:
  ```bash
  updatehome
  ```
- Update NixOS system without updating flake.lock:
  ```bash
  nixupgrade
  ```
- Update the flake.lock dependencies:
  ```bash
  nixupdate
  ```

💡 Note: If the repository was cloned outside `~/teonix`, these aliases might not work.

## Updating Teonix

Whenever you make changes to your Teonix configuration, you can push them to GitHub:

```bash
git add .
git commit -m "Updated Teonix configuration"
git push
```

To pull the latest changes from another machine, run:

```bash
cd ~/teonix
git pull
```

Then apply the updates:

```bash
systemupdate
```

## Final Notes

- The repo should always be cloned in `~` to ensure compatibility with shell aliases.
- Use `--impure` for Desktop (with EDID fix) and normal mode for Laptop.
- Default install (normal mode) is for general use without extra tweaks.
- The project is modular, meaning configs are separated per host (Nixtop/Nixbox).
