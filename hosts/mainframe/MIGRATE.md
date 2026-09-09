# Move the nixbox NVMe to the Xeon mainframe

Boot the **x86_64** NixOS graphical USB. Do **not** boot `#nixbox` on this board. Do **not** click **Install NixOS** in the GUI (that formats disks). You only want the live desktop and a terminal.

This writes `#mainframe` onto the **existing** root. Nothing is wiped.

`nixos-generate-config` only records **mounted** filesystems. Mount every drive where it should live before generating.

## Disks

| Mount on the live USB | UUID | Notes |
|---|---|---|
| `/mnt` | `77da4a95-2958-4385-b35f-9c696d4f9618` | existing Nix root |
| `/mnt/boot` | `547E-412E` | ESP |
| `/mnt/home/teodor/mnt/qvo870` | `c232ec48-5b23-4718-99de-77a7da454343` | Docker data-root |
| `/mnt/home/teodor/mnt/qvo860` | `b3ef6e32-cf62-487b-bc43-03edcfecef09` | |
| `/mnt/home/teodor/mnt/<name>` | *(new drive)* | optional; pick the path |

Swap is `92bea4ff-dcf7-4201-a376-37c10bc4c7dc` (do not mount).

Leave `/mnt/etc/machine-id` alone after root is mounted.

---

## 0. Network

Plug in Ethernet if you can. For Wi‑Fi, use the GNOME tray. Then open **Terminal**.

## 1. Confirm the drives

```bash
lsblk -f
```

Every UUID in the table above must appear (except a new extra disk you do not have yet). If one is missing, stop and fix cables/power.

## 2. Mount root first, then the rest

Paste this as-is if you do **not** have a new extra drive:

```bash
sudo mkdir -p /mnt
sudo mount /dev/disk/by-uuid/77da4a95-2958-4385-b35f-9c696d4f9618 /mnt
sudo mkdir -p /mnt/boot /mnt/home/teodor/mnt/qvo870 /mnt/home/teodor/mnt/qvo860
sudo mount /dev/disk/by-uuid/547E-412E /mnt/boot
sudo mount /dev/disk/by-uuid/c232ec48-5b23-4718-99de-77a7da454343 /mnt/home/teodor/mnt/qvo870
sudo mount /dev/disk/by-uuid/b3ef6e32-cf62-487b-bc43-03edcfecef09 /mnt/home/teodor/mnt/qvo860
```

If you **do** have a new extra disk, find its UUID in `lsblk -f`, pick a name (example `extra`), then:

```bash
sudo mkdir -p /mnt/home/teodor/mnt/extra
sudo mount /dev/disk/by-uuid/PASTE-THE-NEW-UUID /mnt/home/teodor/mnt/extra
```

Check both exist:

```bash
ls /mnt/home/teodor/teonix/flake.nix
ls /mnt/boot
```

The flake is already on that NVMe. Do **not** `git clone` unless `teonix` is actually missing.

## 3. Hardware config from this Xeon + every mounted disk

```bash
sudo nixos-generate-config --root /mnt
sudo cp /mnt/etc/nixos/hardware-configuration.nix \
  /mnt/home/teodor/teonix/hosts/mainframe/hardware-configuration.nix
```

That overwrite is required. The file in git is only a stub from nixbox.

## 4. Install `#mainframe` onto that same root

```bash
sudo nixos-install --flake /mnt/home/teodor/teonix#mainframe --impure --no-root-passwd
```

This builds/downloads the system and writes systemd-boot into the new board’s NVRAM. It does **not** format. Wait until it finishes with no error.

## 5. Reboot onto the NVMe

```bash
reboot
```

Unplug the USB. If firmware still boots the stick or says no OS, open the boot menu once and pick the NVMe / “Linux Boot Manager”.

Log in as **teodor** with your usual password.

If the bar is on the wrong monitor: `hyprctl monitors`.  
If Quickshell still looks like glass: `updatehome`.

---

## Do not

- Use the graphical installer wizard
- `mkfs`, partition, or wipe anything
- Boot the old `#nixbox` system on this board
- Clone the repo over `/mnt/home/teodor/teonix` if it is already there
