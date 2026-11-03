# Changelog

## Unreleased
- Rebranded from CachyOS Live ISO to **Ketup**: os-release, hostname, boot menus (GRUB, syslinux, systemd-boot), splash images, KDE wallpaper, icon theme, MOTD.
- New Calamares setup (branding "ketup", offline install from the live image, btrfs + zstd default).
- Kernel switched to **linux-zen** (Arch `extra`).
- Slimmed package set (no ZFS, Clonezilla, VM-guest extras, CJK fonts, IRC/text browsers, etc.).
- Rust tooling: alacritty, eza, bat, fd, ripgrep, sd, dust, procs, bottom, zoxide, starship, yazi, helix, zellij, tealdeer, paru; sched_ext schedulers (scx).
- Distrobox + Podman, Flatpak + Discover preconfigured.
- Tools: `ketup-logo`, `ketup-apps-location`, `ketup-mirrors`, `ketup-v3`.
- GitHub Actions workflow builds the ISO and publishes releases on `v*` tags.
