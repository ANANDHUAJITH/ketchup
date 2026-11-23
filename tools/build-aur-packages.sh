#!/usr/bin/env bash
# Builds the AUR-only packages the desktop needs (noctalia, matugen) into
# archiso/local-repo/, a pacman repository named "ketchup-local", so that
# packages_desktop.x86_64 can list them and pacstrap can install them.
#
# Run once before buildiso.sh, as a normal user (makepkg refuses root), on an
# Arch-based system or in an archlinux:base-devel container with base-devel, git and
# pacman-contrib installed.
#
# Usage: ./tools/build-aur-packages.sh
set -euo pipefail

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
repo_dir="${src_dir}/archiso/local-repo"
work_dir="$(mktemp -d --suffix=-ketchup-aur)"
trap 'rm -rf "$work_dir"' EXIT

AUR_PKGS=(noctalia matugen)

if [[ "$EUID" -eq 0 ]]; then
    echo "error: run this as a normal user (makepkg refuses root)." >&2
    exit 1
fi

command -v makepkg    >/dev/null || { echo "error: makepkg not found (install base-devel)"; exit 1; }
command -v git        >/dev/null || { echo "error: git not found"; exit 1; }
command -v repo-add   >/dev/null || { echo "error: repo-add not found (pacman-contrib)"; exit 1; }
command -v updpkgsums >/dev/null || { echo "error: updpkgsums not found (pacman-contrib)"; exit 1; }

mkdir -p "$repo_dir"

# point the [ketchup-local] repository in archiso/pacman.conf at this directory
sed -i -E "s#^Server = file://.*#Server = file://${repo_dir}#" "${src_dir}/archiso/pacman.conf"

# The system pacman.conf is only extended with [ketchup-local] after the first package is
# built: repo-add cannot create an empty database, and pacman refuses every transaction
# while an enabled repository has no database file.

for pkg in "${AUR_PKGS[@]}"; do
    echo "==> Building $pkg from AUR ..."
    git clone --depth 1 "https://aur.archlinux.org/${pkg}.git" "${work_dir}/${pkg}"
    (
        cd "${work_dir}/${pkg}"
        # refresh stale checksums in the PKGBUILD
        updpkgsums
        makepkg -s --noconfirm --needed
    )
    cp -v "${work_dir}/${pkg}"/*.pkg.tar.zst "$repo_dir"/
    echo "==> Updating the ketchup-local database ..."
    ( cd "$repo_dir" && repo-add ketchup-local.db.tar.gz ./*.pkg.tar.zst )

    # the database exists now, so the repository can be enabled system-wide (once)
    if ! grep -q "^\[ketchup-local\]" /etc/pacman.conf; then
        printf '\n[ketchup-local]\nSigLevel = Optional TrustAll\nServer = file://%s\n' "$repo_dir" | sudo tee -a /etc/pacman.conf >/dev/null
    fi
    sudo pacman -Sy --noconfirm >/dev/null
done

echo "==> Done. ${#AUR_PKGS[@]} package(s) in ${repo_dir}, pacman.conf updated."
echo "    Now run: ./buildiso.sh"
