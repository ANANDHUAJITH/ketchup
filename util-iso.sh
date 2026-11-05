#!/bin/bash
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

error_function() {
    if [[ -p $logpipe ]]; then
        rm "$logpipe"
    fi
    # first exit all subshells, then print the error
    if (( ! BASH_SUBSHELL )); then
        error "A failure occurred in %s()." "$1"
        plain "Aborting..."
    fi
    umount_fs
    umount_img
    exit 2
}

run_safe() {
    local restoretrap func="$1"
    set -e
    set -E
    restoretrap=$(trap -p ERR)
    trap 'error_function $func' ERR

    if ${verbose}; then
        run_log "$func"
    else
        "$func"
    fi

    eval $restoretrap
    set +E
    set +e
}

check_umount() {
    if mountpoint -q "$1"; then
        umount -l "$1"
    fi
}

trap_exit() {
    local sig=$1; shift
    error "$@"
    umount_fs
    trap -- "$sig"
    kill "-$sig" "$$"
}

generate_motd() {
    cat << 'EOF' > ${src_dir}/archiso/airootfs/etc/motd
[38;2;230;58;46m _  __    _       _
| |/ /___| |_ ___| |__  _   _ _ __
| ' // _ \ __/ __| '_ \| | | | '_ \
| . \  __/ || (__| | | | |_| | |_) |
|_|\_\___|\__\___|_| |_|\__,_| .__/
                             |_|[0m

Welcome to [38;2;230;58;46mKetchup[0m - a fast, slim Arch-based system on the linux-zen kernel.
Run [1mketchup-install[0m to start the installer (or use the desktop icon).

Rebrand name/logo/hostname:    sudo ketchup-rebrand   (logo only: ketchup-logo)
Learn how the OS works:        ketchup-lens sim   |   ketchup-lens trace -- ./program
Check security / IRQ trouble:  sudo ketchup-audit   |   ketchup-irqfix 27
Choose where apps are stored:  ketchup-apps-location
Study labs (net, kmod, boot):  ketchup-lab list   |   notes: /usr/share/doc/ketchup/STUDY.md
More dev tools:                ketchup-devtools list
Something wrong? Diagnostics:  ketchup-doctor
Containers (distrobox):        distrobox create -n arch -i archlinux && distrobox enter arch

Built on Arch Linux archiso and the CachyOS Live ISO (GPL-3.0).
EOF
}

fetch_cachyos_mirrorlist() {
    mkdir -p ${src_dir}/archiso/airootfs/etc/pacman.d
    local _mirrorlist_url="https://github.com/CachyOS/CachyOS-PKGBUILDS/raw/master/cachyos-mirrorlist/cachyos-mirrorlist"

    curl -sSL "${_mirrorlist_url}" > ${src_dir}/archiso/airootfs/etc/pacman.d/cachyos-mirrorlist
}

# CachyOS' calamares is sometimes built against an older boost than Arch currently ships
# (error: "libboost_python.so.1.91.0: cannot open shared object file"). Pull the matching
# old boost-libs from the Arch Linux Archive and make them available under /usr/lib/ketchup-compat.
# Override the version with BOOST_COMPAT_VERSION=1.91.0 ; set it to "none" to skip.
fetch_boost_compat() {
    local _ver="${BOOST_COMPAT_VERSION:-1.91.0}"
    [ "${_ver}" = "none" ] && return 0
    local _dest="${src_dir}/archiso/airootfs/usr/lib/ketchup-compat"
    local _base="https://archive.archlinux.org/packages/b/boost-libs/"
    local _tmp; _tmp="$(mktemp -d)"
    local _file
    _file="$(curl -fsSL "${_base}" | grep -o "boost-libs-${_ver//./\\.}-[0-9]*-x86_64\.pkg\.tar\.zst" | sort -uV | tail -n1)"
    if [ -z "${_file}" ]; then
        echo "WARNING: boost-libs ${_ver} not found in the Arch Linux Archive; calamares may fail to start" >&2
        rm -rf "${_tmp}"; return 0
    fi
    curl -fsSL -o "${_tmp}/${_file}" "${_base}${_file}" || { echo "WARNING: could not download ${_file}" >&2; rm -rf "${_tmp}"; return 0; }
    mkdir -p "${_dest}"
    bsdtar -xf "${_tmp}/${_file}" -C "${_tmp}" --include 'usr/lib/libboost*' 2>/dev/null
    cp -a "${_tmp}"/usr/lib/libboost*.so."${_ver}"* "${_dest}/" 2>/dev/null
    mkdir -p "${src_dir}/archiso/airootfs/etc/ld.so.conf.d"
    echo "/usr/lib/ketchup-compat" > "${src_dir}/archiso/airootfs/etc/ld.so.conf.d/ketchup-compat.conf"
    echo "boost compat: installed $(ls "${_dest}" | wc -l) libs from ${_file}"
    rm -rf "${_tmp}"
}

change_grub_version() {
    local _version="$1"
    sed -i "s/KETCHUP_VERSION=\".*\"/KETCHUP_VERSION=\"${_version}\"/" ${src_dir}/archiso/grub/grub.cfg
}

generate_environment() {
    local _profile="$1"
    if [ "$_profile" == "desktop" ]; then
        cat << 'EOF' > ${src_dir}/archiso/airootfs/etc/environment
ZPOOL_VDEV_NAME_PATH=1
EOF
    fi
}

generate_version_tag() {
    local _profile="$1"
    local _version="$2"
    if [ "$_profile" == "desktop" ]; then
        echo "${_version}" > ${src_dir}/archiso/airootfs/etc/version-tag
    fi
}

generate_edition_tag() {
    local _edition="$1"
    echo "${_edition}" > ${src_dir}/archiso/airootfs/etc/edition-tag
}

modify_mkarchiso() {
    local _is_hack_applied="$(grep -q 'archlinux-keyring-wkd-sync.timer' /usr/bin/mkarchiso; echo $?)"
    if [ $_is_hack_applied -ne 0 ]; then
        msg "Patching mkarchiso with disabled arch keyrings timer..."

        sudo sed 's/_run_once _make_customize_airootfs/_run_once _make_customize_airootfs\n\trm -f "${pacstrap_dir}\/usr\/lib\/systemd\/system\/timers.target.wants\/archlinux-keyring-wkd-sync.timer"\n/' -i /usr/bin/mkarchiso
    else
        msg "mkarchiso is already patched!"
    fi
}

prepare_profile(){
    profile=$1

    info "Profile: [%s]" "${profile}"

    local _iso_version="$(date +%y%m%d)"
    change_grub_version "${_iso_version}"

    # Fetch up-to-date CachyOS repo mirrorlist (upstream repo)
    fetch_cachyos_mirrorlist
    fetch_boost_compat

    generate_motd

    rm -f ${src_dir}/archiso/airootfs/etc/systemd/system/display-manager.service
    if [ "$profile" == "desktop" ]; then
        cp ${src_dir}/archiso/packages_desktop.x86_64 ${src_dir}/archiso/packages.x86_64
        ln -sf /usr/lib/systemd/system/plasmalogin.service ${src_dir}/archiso/airootfs/etc/systemd/system/display-manager.service
    else
        die "Unknown profile: [%s]" "${profile}"
    fi

    generate_environment "${profile}"

    # Write out version to be able to check ISO version
    generate_version_tag "${profile}" "${_iso_version}"

    # Write out edition to be able to check ISO edition
    generate_edition_tag "${profile}"

    iso_file=$(gen_iso_fn).iso
}

# ---------------------------------------------------------------------------
# Limine: mkarchiso only knows syslinux/systemd-boot/grub, so it first builds a stock ISO
# (that stays as scaffolding), then we re-pack the very same file tree with Limine as the
# only bootloader (BIOS + UEFI, hybrid so `dd` to USB works).
# Test against a local Limine checkout with:  LIMINE_SHARE=/path/to/limine LIMINE_BIN=/path/to/limine/limine
# ---------------------------------------------------------------------------
make_limine_iso() {
    local _iso_out="$1"                      # path of the ISO to (over)write
    local iso_dir="${work_dir}/iso"
    local share="${LIMINE_SHARE:-/usr/share/limine}"
    local limine_bin="${LIMINE_BIN:-limine}"
    local tmpl="${src_dir}/archiso/limine/limine.conf.in"
    local f label

    [[ -d "${iso_dir}/arch" ]] || die "Limine: ${iso_dir}/arch not found (did mkarchiso fail?)"
    for f in limine-bios.sys limine-bios-cd.bin limine-uefi-cd.bin BOOTX64.EFI; do
        [[ -r "${share}/${f}" ]] || die "Limine: ${share}/${f} missing - install the 'limine' package"
    done
    command -v "${limine_bin}" >/dev/null || die "Limine: 'limine' command not found"
    command -v xorriso >/dev/null || die "Limine: xorriso not found (package libisoburn)"

    label="$(declare -A file_permissions; source "${src_dir}/archiso/profiledef.sh"; echo "${iso_label}")"

    msg2 "Limine: removing syslinux/grub/systemd-boot files from the ISO tree"
    sudo rm -rf "${iso_dir}/syslinux" "${iso_dir}/boot/syslinux" "${iso_dir}/boot/grub" \
                "${iso_dir}/EFI" "${iso_dir}/loader" "${iso_dir}/boot/limine"
    sudo mkdir -p "${iso_dir}/boot/limine" "${iso_dir}/EFI/BOOT"

    # optional pieces: microcode, memtest, EFI shell (only if mkarchiso staged them)
    local ucode="" tools=""
    local uc dir   # mkarchiso stages microcode under <install_dir>/boot/ (newer) or /boot/ (older)
    for uc in amd-ucode.img intel-ucode.img; do
        for dir in arch/boot boot; do
            if [[ -f "${iso_dir}/${dir}/${uc}" ]]; then ucode+="    module_path: boot():/${dir}/${uc}"$'\n'; break; fi
        done
    done
    ucode="${ucode%$'\n'}"
    if [[ -f "${iso_dir}/boot/memtest86+/memtest.efi" ]]; then
        tools+=$'\n/Memtest86+ (RAM test, UEFI)\n    protocol: efi\n    path: boot():/boot/memtest86+/memtest.efi\n'
    fi
    if [[ -f "${iso_dir}/boot/memtest86+/memtest" ]]; then
        tools+=$'\n/Memtest86+ (RAM test, BIOS)\n    protocol: linux\n    path: boot():/boot/memtest86+/memtest\n'
    fi
    if [[ -f "${iso_dir}/shellx64.efi" ]]; then
        tools+=$'\n/UEFI Shell\n    protocol: efi\n    path: boot():/shellx64.efi\n'
    fi

    # render limine.conf (keep indentation of nested entries for the microcode lines)
    local conf; conf="$(mktemp)"
    UCODE="${ucode}" TOOLS="${tools}" awk '
        /^@MICROCODE@$/ { if (ENVIRON["UCODE"] != "") print ENVIRON["UCODE"]; next }
        /^@TOOLS@$/     { printf "%s", ENVIRON["TOOLS"]; next }
        { print }' "${tmpl}" \
      | sed -e "s|%INSTALL_DIR%|arch|g" -e "s|%ARCH%|x86_64|g" -e "s|%ISO_LABEL%|${label}|g" > "${conf}"
    # KETCHUP_LIVE_EXTRA="console=ttyS0" appends extra kernel arguments to every live entry (serial CI/debug)
    [[ -n "${KETCHUP_LIVE_EXTRA:-}" ]] && sed -i -E "s|^([[:space:]]*cmdline: .*)$|\\1 ${KETCHUP_LIVE_EXTRA}|" "${conf}"

    sudo install -Dm644 "${conf}" "${iso_dir}/boot/limine/limine.conf"
    rm -f "${conf}"
    sudo install -Dm644 "${src_dir}/archiso/limine/wallpaper.png" "${iso_dir}/boot/limine/wallpaper.png"
    for f in limine-bios.sys limine-bios-cd.bin limine-uefi-cd.bin; do
        sudo install -Dm644 "${share}/${f}" "${iso_dir}/boot/limine/${f}"
    done
    sudo install -Dm644 "${share}/BOOTX64.EFI" "${iso_dir}/EFI/BOOT/BOOTX64.EFI"
    [[ -r "${share}/BOOTIA32.EFI" ]] && sudo install -Dm644 "${share}/BOOTIA32.EFI" "${iso_dir}/EFI/BOOT/BOOTIA32.EFI"

    msg2 "Limine: building ${_iso_out} (label ${label})"
    local tmp_iso="${_iso_out}.limine.tmp"
    sudo rm -f "${tmp_iso}"
    sudo xorriso -as mkisofs \
        -iso-level 3 -full-iso9660-filenames -joliet -joliet-long -rational-rock \
        -volid "${label}" -appid "Ketchup Live/Install Medium" -publisher "Ketchup" \
        -b boot/limine/limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
        --efi-boot boot/limine/limine-uefi-cd.bin -efi-boot-part --efi-boot-image --protective-msdos-label \
        "${iso_dir}" -o "${tmp_iso}"
    sudo "${limine_bin}" bios-install "${tmp_iso}"
    sudo mv -f "${tmp_iso}" "${_iso_out}"
    sudo chown "${USER}" "${_iso_out}" 2>/dev/null || true
    msg2 "Limine: done"
}

run_build() {
    prepare_profile "$1"
    local _profile="$1"

    msg "Prepare [work: ${work_dir}, out: ${outFolder}]"

    if $verbose; then
        msg2 "Making mkarchiso verbose"
        sudo sed -i 's/quiet="y"/quiet="n"/g' /usr/bin/mkarchiso
    fi

    if $clean_first; then
        msg2 "Deleting the build folder if one exists - takes some time"
        umount_fs
        [ -d ${work_dir} ] && sudo rm -rf ${work_dir}
    fi

    msg2 "Copying the Archiso folder to build work"
    mkdir -p ${work_dir}
    cp -r archiso ${work_dir}/archiso

    msg "Start [Build ISO]"

    # insert removal of archlinux keyrings timer on the ISO before pack
    modify_mkarchiso

    [ -d "$outFolder/$_profile" ] || mkdir -p "$outFolder/$_profile"
    cd ${work_dir}/archiso/
    sudo mkarchiso -v -w ${work_dir} -o "$outFolder/$_profile" ${work_dir}/archiso/
    sudo chown $USER $outFolder

    # Replace the stock (grub/syslinux) ISO with a Limine one
    make_limine_iso "$outFolder/$_profile/ketchup-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)-x86_64.iso"

    cp ${work_dir}/iso/arch/pkglist.x86_64.txt "$outFolder/$_profile/$(gen_iso_fn).pkgs.txt"
    mv "$outFolder/$_profile/ketchup-$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)-x86_64.iso" "$outFolder/$_profile/${iso_file}"

    msg "Done [Build ISO] ${iso_file}"
    msg "Finished building [%s]" "${_profile}"

    cd "$outFolder/$_profile"
    for f in $(find . -maxdepth 1 -name '*.iso' | cut -d'/' -f2); do
        if [[ ! -e $f.sha256 ]]; then
            create_chksums $f
        elif [[ $f -nt $f.sha256 ]]; then
            create_chksums $f
        else
            info "checksums for [$f] already created"
        fi
        if [[ ! -e $f.sig ]]; then
            sign_with_key $f
        elif [[ $f -nt $f.sig ]]; then
            rm $f.sig
            sign_with_key $f
        else
            info "signature file for [$f] already created"
        fi
    done
    show_elapsed_time "${FUNCNAME}" "${timer_start}"
    if [[ "$build_in_ram" == "true" && "$remove_build_dir" == "false" ]]; then
        msg "!!! Remember to remove $work_dir !!!"
        msg2 "sudo rm -rf $work_dir"
    fi
    if [[ "$remove_build_dir" == "true" ]]; then
        msg "Automatically removing build directory ($work_dir)..."
        umount_fs
        [ -d ${work_dir} ] && sudo rm -rf ${work_dir}
        msg2 "Removed"
    fi
}

gen_iso_fn(){
    local vars=() name
    vars+=("ketchup")
    [[ -n ${profile} ]] && vars+=("${profile}")

    vars+=("linux")
    vars+=("$(date +%y%m%d)")

    for n in ${vars[@]}; do
        name=${name:-}${name:+-}${n}
    done

    echo $name
}
