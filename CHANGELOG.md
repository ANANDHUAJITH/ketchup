# Changelog

## Unreleased
- **Fix: boot-medium label collision.** `make_limine_iso` passed `-hfsplus -apm-block-size 2048` to xorriso without realizing the HFS+ volume always inherits `-volid` (xorriso has no separate label option for it), so the hybrid USB ended up with *two* `KETCHUP_<date>`-labelled filesystems: the real ISO9660 one and a bogus HFS+/APM partition. `/dev/disk/by-label/KETCHUP_<date>` could then resolve to the HFS+ partition instead of the ISO9660 volume, and archiso's boot-medium mount failed (`wrong fs type, bad option, bad superblock`), dropping to the initramfs recovery shell. Dropped `-hfsplus -apm-block-size 2048` entirely - it only ever existed for pre-2006 PowerPC Mac "Startup Disk" boot; BIOS and UEFI El Torito boot (already present) cover every machine that matters, Macs included. Rebuild the ISO and re-flash the USB to pick this up; existing bad USBs can be recovered without reflashing (see `docs/` boot-recovery note) but should still be re-flashed with the fixed ISO.
- **Blue mode:** `mythical-blue-ketchup` swaps the logo/icon theme to a blue variant for the current login session only (auto-reverts on logout or restart via `ketchup-blue-reset-check`, or immediately with `the-legacy-red-ketchup`). While it's on: `ketchup-blue-vault` (a gocryptfs-encrypted folder) and `ketchup-blue-apps` (a disposable Distrobox sandbox for extra software) unlock, and both wipe with one command.
- **About Ketchup:** new `about.html` (app menu: *About Ketchup*) renders the project README live from GitHub.
- **Name:** the project is **Ketchup** everywhere (files, commands `ketchup-*`, ISO label `KETCHUP_*`, Calamares branding, docs).
- **New mascot branding:** logo, icon theme, KDE wallpapers, Calamares images, Limine/GRUB/syslinux splash generated from the new mascot SVGs (`tools/make-assets.py`); all five poses shipped in `/usr/share/ketchup/mascot/`.
- **Limine** replaces syslinux/systemd-boot/GRUB on the ISO (BIOS + UEFI + hybrid USB) via `make_limine_iso`; installed systems use Limine on UEFI (ESP mounted at `/boot`), with `ketchup-limine` (install/update/status/pin), a pacman hook, optional BLAKE2b hash pinning, Windows chainload entry, and automatic GRUB fallback on BIOS machines with an unreadable `/boot`. Tested in QEMU: BIOS CD, UEFI CD, UEFI USB, installed-style ESP, pinned and tampered kernels.
- **IRQ 27 "nobody cared":** `noirqdebug` on all default boot entries; live menu *IRQ troubleshooting* submenu; new `ketchup-irqfix` identifies the owning device and applies a fix; `ketchup-doctor` includes it.
- **Ketchup Lens:** `ketchup-lens trace|sim|latency|hw|samples` - interactive report of a real program run, and the KetchupVM simulator (tested by `tools/test-kvm.js`).
- **Security:** `ketchup-audit`; hardening sysctls; installed system verifies CachyOS repo signatures once the keyring is imported; live boot entries load CPU microcode when mkarchiso stages it (the old menus never did); removed the stale self-extracting `fix-calamares-conflict.sh`; `SECURITY-EVALUATION.md`; `docs/OWN-REPO.md`.
- CI: shellcheck skips the Python tool; Python compile check and simulator tests added.
- Live boot no longer copies the image to RAM (`copytoram=n`): lower idle RAM, faster boot. Compat boot entry with `irqpoll pci=nomsi` for "irq N: nobody cared" hangs.
- Squashfs back to zstd (faster to decompress). ISO may be split into parts for GitHub Releases.
- Calamares boost fix: matching old boost-libs fetched from the Arch Linux Archive at build time.
- NetworkManager: removed the 30 s global start timeout, added restart-on-failure.
- New: `ketchup-rebrand`, `ketchup-doctor`, `ketchup-lab`, `ketchup-devtools`, study guide; developer and networking packages.
- Rebranded from CachyOS Live ISO to **Ketchup**: os-release, hostname, boot menus (GRUB, syslinux, systemd-boot), splash images, KDE wallpaper, icon theme, MOTD.
- New Calamares setup (branding "ketchup", offline install from the live image, btrfs + zstd default).
- Kernel switched to **linux-zen** (Arch `extra`).
- Slimmed package set (no ZFS, Clonezilla, VM-guest extras, CJK fonts, IRC/text browsers, etc.).
- Rust tooling: alacritty, eza, bat, fd, ripgrep, sd, dust, procs, bottom, zoxide, starship, yazi, helix, zellij, tealdeer, paru; sched_ext schedulers (scx).
- Distrobox + Podman, Flatpak + Discover preconfigured.
- Tools: `ketchup-logo`, `ketchup-apps-location`, `ketchup-mirrors`, `ketchup-v3`.
- GitHub Actions workflow builds the ISO and publishes releases on `v*` tags.
