# Move the nixbox NVMe to the Xeon mainframe

Do **not** boot `#nixbox` on the new board. From a stock NixOS installer USB, generate hardware config for every mounted disk, copy it into the flake, and install `#mainframe` onto the existing root (no format).

`nixos-generate-config` only records **mounted** filesystems. Mount the extra drive where it should live before generating.

## Disks

| Mount on the live USB | UUID | Notes |
|---|---|---|
| `/mnt` | `77da4a95-2958-4385-b35f-9c696d4f9618` | existing Nix root |
| `/mnt/boot` | `547E-412E` | ESP |
| `/mnt/home/teodor/mnt/qvo870` | `c232ec48-5b23-4718-99de-77a7da454343` | Docker data-root |
| `/mnt/home/teodor/mnt/qvo860` | `b3ef6e32-cf62-487b-bc43-03edcfecef09` | |
| `/mnt/home/teodor/mnt/<name>` | *(new drive)* | pick the path; generate-config writes it |

Swap is `92bea4ff-dcf7-4201-a376-37c10bc4c7dc` (no extra mount).

## Commands

```bash
# 1. Mount everything (root first)
sudo mkdir -p /mnt
sudo mount /dev/disk/by-uuid/77da4a95-2958-4385-b35f-9c696d4f9618 /mnt
sudo mkdir -p /mnt/boot /mnt/home/teodor/mnt/qvo870 /mnt/home/teodor/mnt/qvo860
sudo mount /dev/disk/by-uuid/547E-412E /mnt/boot
sudo mount /dev/disk/by-uuid/c232ec48-5b23-4718-99de-77a7da454343 /mnt/home/teodor/mnt/qvo870
sudo mount /dev/disk/by-uuid/b3ef6e32-cf62-487b-bc43-03edcfecef09 /mnt/home/teodor/mnt/qvo860
# extra drive — change NAME and find its UUID with `lsblk -f`
sudo mkdir -p /mnt/home/teodor/mnt/NAME
sudo mount /dev/disk/by-uuid/NEW-UUID /mnt/home/teodor/mnt/NAME

# 2. Hardware config from this machine + every mounted disk
sudo nixos-generate-config --root /mnt
sudo cp /mnt/etc/nixos/hardware-configuration.nix \
  /mnt/home/teodor/teonix/hosts/mainframe/hardware-configuration.nix

# 3. Install #mainframe onto the existing root (writes systemd-boot to the new NVRAM)
sudo nixos-install --flake /mnt/home/teodor/teonix#mainframe --impure --no-root-passwd
```

Reboot from the NVMe. Unplug the USB. If firmware does not pick the disk, choose it once in the boot menu.

After login: `hyprctl monitors` if the bar is on the wrong output; `updatehome` if Quickshell still looks like glass.
