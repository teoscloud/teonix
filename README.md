# Teonix

Teonix is a modular, flake-based NixOS configuration integrated with Home Manager. This repository provides a fully reproducible, customizable NixOS setup designed for multiple devices (e.g., desktop and laptop), allowing you to share common modules while tailoring host-specific settings.

## Features

- **Modular Structure**
  - **`hosts/`**: Contains host-specific configurations (e.g., `nixbox`, `nixtop`).
  - **`modules/`**: Contains shared NixOS modules for core settings, services, hardware, environment, and customization.
  - **`home/`**: Manages user configurations via Home Manager, including dotfile symlinking.
  - **`customfiles/`**: Contains additional resources (e.g., EDID files).
  - **`scripts/`**: Contains utility scripts.
- **Flake-Based Setup**
  - Uses Nix flakes for reproducibility, easier updates, and modularity.
- **Home Manager Integration**
  - Manages user-level settings (dotfiles, shell configuration, installed applications) in a declarative manner.
- **Device-Specific Customization**
  - Customize settings such as monitor resolution, port configuration, and VRR on a per-device basis.


## How to Use

### Prerequisites

- **Nix & Flakes:**  
  Ensure you have [Nix](https://nixos.org) installed with flake support enabled.

- **NixOS 25.05 or Later:**  
  This configuration is designed for NixOS 25.05. Adjustments may be necessary for other versions.

### Getting Started

1. **Clone the Repository**

   Clone this repository to your local machine:
   ```sh
   git clone git@github.com:teoscloud/teonix.git
   cd teonix


2. **Update Flake Inputs**

   Update the flake inputs to ensure you have the latest versions:
   ```sh
   nix flake update

3. **Rebuild Your NixOS System**

   For your desktop (nixbox), run:
   ```sh
   sudo nixos-rebuild switch --flake .#nixbox --impure
    ```
   For a different host configuration (e.g., nixtop), adjust the flake target accordingly:
   ```sh
   sudo nixos-rebuild switch --flake .#nixtop --impure

4. **Apply Home Manager Configuration**

   Home Manager manages your home directory, dotfiles, and user-specific settings:
   ```sh
   home-manager switch --flake .#teodor
