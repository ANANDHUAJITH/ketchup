#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="ketup"
iso_label="KETUP_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Ketup <https://github.com/ketup-os/ketup-iso>"
iso_application="Ketup Live/Install Medium"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux' 'uefi.grub')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '19' '-b' '1M')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/gshadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/etc/polkit-1/rules.d"]="0:0:750"
  ["/etc/sudoers.d"]="0:0:750"
  ["/etc/sudoers.d/g_wheel"]="0:0:440"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/ketup-install"]="0:0:755"
  ["/usr/local/bin/ketup-pre-initramfs"]="0:0:755"
  ["/usr/local/bin/ketup-post-install"]="0:0:755"
  ["/usr/local/bin/ketup-logo"]="0:0:755"
  ["/usr/local/bin/ketup-apps-location"]="0:0:755"
  ["/usr/local/bin/ketup-first-login"]="0:0:755"
  ["/usr/local/bin/ketup-mirrors"]="0:0:755"
  ["/usr/local/bin/ketup-v3"]="0:0:755"
  ["/usr/local/bin/ketup-rebrand"]="0:0:755"
  ["/usr/local/bin/ketup-doctor"]="0:0:755"
  ["/usr/local/bin/ketup-lab"]="0:0:755"
  ["/usr/local/bin/ketup-devtools"]="0:0:755"
  ["/usr/local/bin/ketup-firstboot"]="0:0:755"
  ["/usr/local/bin/pkexec-wrapper"]="0:0:755"
  ["/etc/skel/Desktop/ketup-install.desktop"]="0:0:755"
)
