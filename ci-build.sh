#!/bin/bash
# Builds the ISO inside an archlinux:base-devel container (see .github/workflows/build-iso.yml).
set -euo pipefail
cd "$(dirname "$0")"

sed -i '/^\[options\]/a DisableSandbox' /etc/pacman.conf
pacman -Syu --noconfirm --needed archlinux-keyring curl
pacman-key --init
pacman-key --populate archlinux

# Install cachyos-keyring from a downloaded file first; its pacman hook imports the signing
# key, so the [cachyos] repo below is verified like the Arch repos (no TrustAll).
cachyos_tmp="$(mktemp -d)"
trap 'rm -rf "$cachyos_tmp"' EXIT
cachyos_keyring_pkg="$(curl -fsSL https://mirror.cachyos.org/repo/x86_64/cachyos/ \
    | grep -o 'cachyos-keyring-[0-9][^"]*-any\.pkg\.tar\.zst' | sort -V | tail -n1)"
[ -n "$cachyos_keyring_pkg" ] || { echo "error: could not find cachyos-keyring on the mirror" >&2; exit 1; }
curl -fsSL -o "$cachyos_tmp/$cachyos_keyring_pkg" \
    "https://mirror.cachyos.org/repo/x86_64/cachyos/$cachyos_keyring_pkg"
pacman -U --noconfirm "$cachyos_tmp/$cachyos_keyring_pkg"
rm -rf "$cachyos_tmp"

# CachyOS repo: calamares, ananicy-cpp, paru and the keyring come from here.
sed -i '/^\[core\]$/i [cachyos]\nServer = https://mirror.cachyos.org/repo/$arch/$repo\n' /etc/pacman.conf
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
