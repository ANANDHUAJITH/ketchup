# Changelog

## Unreleased
- Live boot no longer copies the image to RAM (`copytoram=n`): lower idle RAM, faster boot. Compat boot entry with `irqpoll pci=nomsi` for "irq N: nobody cared" hangs.
- Squashfs back to zstd (faster to decompress). ISO may be split into parts for GitHub Releases.
- Calamares boost fix: matching old boost-libs fetched from the Arch Linux Archive at build time.
- NetworkManager: removed the 30 s global start timeout, added restart-on-failure.
- New: `ketup-rebrand`, `ketup-doctor`, `ketup-lab`, `ketup-devtools`, study guide; developer and networking packages.
- Rebranded from CachyOS Live ISO to **Ketup**: os-release, hostname, boot menus (GRUB, syslinux, systemd-boot), splash images, KDE wallpaper, icon theme, MOTD.
- New Calamares setup (branding "ketup", offline install from the live image, btrfs + zstd default).
- Kernel switched to **linux-zen** (Arch `extra`).
- Slimmed package set (no ZFS, Clonezilla, VM-guest extras, CJK fonts, IRC/text browsers, etc.).
- Rust tooling: alacritty, eza, bat, fd, ripgrep, sd, dust, procs, bottom, zoxide, starship, yazi, helix, zellij, tealdeer, paru; sched_ext schedulers (scx).
- Distrobox + Podman, Flatpak + Discover preconfigured.
- Tools: `ketup-logo`, `ketup-apps-location`, `ketup-mirrors`, `ketup-v3`.
- GitHub Actions workflow builds the ISO and publishes releases on `v*` tags.
