#!/bin/bash
# Builds the ISO inside an archlinux:base-devel container (see .github/workflows/build-iso.yml).
set -euo pipefail
cd "$(dirname "$0")"

sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf
pacman-key --init
pacman-key --populate archlinux
# CachyOS repo: calamares, ananicy-cpp, paru and the keyring come from here.
sed -i '/^\[core\]$/i [cachyos]\nSigLevel = Optional TrustAll\nServer = https://mirror.cachyos.org/repo/$arch/$repo\n' /etc/pacman.conf
pacman -Syu --noconfirm --needed archiso mkinitcpio-archiso squashfs-tools grub git sudo curl dosfstools mtools libisoburn limine

useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers
chown -R builder:builder .

# noctalia and matugen are AUR-only: build them into archiso/local-repo/ (the
# "ketchup-local" repo) so the package list can install them like any other package.
pacman -S --noconfirm --needed pacman-contrib
sudo -H -E -u builder ./tools/build-aur-packages.sh

sudo -H -E -u builder ./buildiso.sh -w
ls -lh out/desktop/
