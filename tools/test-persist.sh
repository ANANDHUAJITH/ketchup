#!/bin/bash
# Checks ketchup-persist's partition planning on an image laid out like the Limine ISO
# (GPT inside the ISO, written to a larger "stick"). Needs xorriso, mkfs.fat, sfdisk, isosize.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
tool="$here/../archiso/airootfs/usr/local/bin/ketchup-persist"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cd "$work"

fail() { echo "FAIL: $*" >&2; exit 1; }

mkdir -p iso/boot/limine iso/arch
head -c 4096 /dev/urandom > iso/boot/limine/limine-bios-cd.bin
dd if=/dev/zero of=iso/boot/limine/limine-uefi-cd.bin bs=1M count=4 status=none
mkfs.fat -F12 iso/boot/limine/limine-uefi-cd.bin > /dev/null
head -c 64M /dev/urandom > iso/arch/airootfs.sfs
xorriso -as mkisofs -iso-level 3 -rational-rock -volid KETCHUP_TEST \
    -b boot/limine/limine-bios-cd.bin -no-emul-boot -boot-load-size 4 -boot-info-table \
    --efi-boot boot/limine/limine-uefi-cd.bin -efi-boot-part --efi-boot-image --protective-msdos-label \
    iso -o stick.img 2> /dev/null
iso_bytes=$(isosize stick.img)
cp stick.img orig.img
truncate -s 1G stick.img

# shellcheck source=/dev/null
source "$tool"

isoend=$(iso_end stick.img stick.img)
[ "$isoend" -eq $(( iso_bytes / 512 )) ] || fail "iso_end $isoend, expected $(( iso_bytes / 512 ))"

read -r start size <<< "$(plan stick.img "$isoend")"
[ "$start" -ge "$isoend" ]        || fail "partition starts inside the ISO ($start < $isoend)"
[ $(( start % 2048 )) -eq 0 ]     || fail "start $start is not 1 MiB aligned"
[ "$size" -ge $(( 512 * 2048 )) ] || fail "size $size is too small"
[ $(( start + size )) -lt "$(disk_sectors stick.img)" ] || fail "partition runs past the end of the disk"

printf 'start=%s, size=%s, type=L\n' "$start" "$size" | sfdisk --append --quiet stick.img 2> /dev/null
sfdisk -d stick.img | awk -v s="$start" '$0 ~ ("start= *" s ",") { found = 1 } END { exit !found }' \
    || fail "new partition not found in the table"

# Everything but the system area and the old backup GPT at the end of the ISO must be unchanged.
cmp -i 32768 -n $(( iso_bytes - 32768 - 64 * 512 )) orig.img stick.img || fail "ISO data changed"
xorriso -indev stick.img -find / -maxdepth 1 2> /dev/null | grep -q "'/arch'" || fail "ISO is no longer readable"

# A stick with no room after the ISO must be refused.
truncate -s "$(( iso_bytes + 100 * 1024 * 1024 ))" small.img
cp orig.img small.img.tmp && dd if=small.img.tmp of=small.img conv=notrunc status=none && rm small.img.tmp
if ( plan small.img "$isoend" ) > /dev/null 2>&1; then
    read -r _ s2 <<< "$(plan small.img "$isoend")"
    [ "$s2" -lt $(( 512 * 2048 )) ] || fail "100 MiB of free space reported as usable"
fi

parse_size 8G | grep -qx 16777216 || fail "parse_size 8G"
parse_size 4096M | grep -qx 8388608 || fail "parse_size 4096M"

echo "test-persist: OK (start sector $start, $(( size / 2048 )) MiB)"
