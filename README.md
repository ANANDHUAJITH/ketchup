<p align="center"><img src="archiso/airootfs/usr/share/ketup/logo.svg" width="480" alt="Ketup" style="background:#14090a"></p>

# Ketup

A fast, slim, Arch-based desktop OS: **KDE Plasma + linux-zen + Rust tooling + Distrobox**, built from the
[CachyOS Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO) profile and rebranded. The ISO is built by GitHub Actions.

## What's different from the CachyOS live ISO

| Area | Ketup |
|---|---|
| Kernel | `linux-zen` from Arch `extra` (desktop-oriented patch set) |
| Tuning | Ketup's own sysctl, udev I/O schedulers, zram (zstd), BBR, `ananicy-cpp`, `scx_lavd`, `systemd-oomd`, weekly `fstrim` |
| Installer | Calamares with a new "ketup" branding and config; offline install of the live image; btrfs + zstd + subvolumes default |
| Rust tools | alacritty, eza, bat, fd, ripgrep, sd, dust, procs, bottom, zoxide, starship, yazi, helix, zellij, tealdeer, paru |
| Containers | Distrobox + Podman (rootless, preconfigured) |
| Apps | Flatpak + Flathub + Discover |
| Look | Dark Breeze, tomato accent, Ketup icon theme, wallpaper, boot splash |
| Slimming | No ZFS, Clonezilla, VM-guest agents beyond QEMU/SPICE, modem/ppp/VPN extras, CJK fonts, IRC/text browsers, GParted, Kate, etc. |

## Build

Push to GitHub: `.github/workflows/build-iso.yml` builds the ISO (artifact on every run; GitHub Release on tags like `v2026.11`).

Locally on Arch/CachyOS:

```bash
sudo pacman -S archiso mkinitcpio-archiso squashfs-tools grub git
./buildiso.sh -v        # ISO ends up in out/desktop/
```

Edit `archiso/packages_desktop.x86_64` to add or remove packages.

## Tools shipped on the ISO

* **`ketup-logo`** - change the logo after boot (menu button, About, installer). `ketup-logo set my.svg` (or `.png`), `sudo ketup-logo set my.svg` for all users, `ketup-logo reset`. Also in the app menu as *Change Ketup Logo*.
* **`ketup-apps-location`** - choose where apps are installed: `ketup-apps-location flatpak /mnt/bigdrive`, `... distrobox /mnt/bigdrive`, or run it with no arguments for a dialog. Pacman packages always go to `/usr`; to put them on another disk, mount that disk at `/opt` or `/var` via fstab.
* **`ketup-mirrors`** - rank the fastest Arch mirrors.
* **`ketup-v3`** - opt in to CPU-optimised x86-64-v3 packages from the CachyOS repos (`ketup-v3 off` to undo).

## Rebranding checklist

Replace `ketup-os/ketup-iso` URLs in `archiso/airootfs/etc/os-release`, `profiledef.sh` and `archiso/airootfs/usr/share/calamares/branding/ketup/branding.desc` with your repo.
Default time zone in the installer is Asia/Kolkata (`archiso/airootfs/etc/calamares/modules/locale.conf`).

## Credits & license

GPL-3.0. Based on the CachyOS Live ISO profile and Arch Linux `archiso`. Ketup is an independent project and is not affiliated with CachyOS.
