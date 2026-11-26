#!/bin/bash
# Persistence (cow_label) and other live-medium options belong to the live USB only. This
# generates an installed system's Limine menu in a scratch tree and checks that none of them
# can reach it, even when they are planted in the files the menu is built from.
set -euo pipefail

here="$(cd "$(dirname "$0")/.." && pwd)"
bin="$here/archiso/airootfs/usr/local/bin"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

root="$work/root"; share="$work/limine-share"
mkdir -p "$root/etc/kernel" "$root/etc/ketchup" "$root/boot" "$share"
echo 'NAME="Ketchup"' > "$root/etc/os-release"
printf 'UUID=aaaa-1111 / btrfs rw,subvol=/@,compress=zstd 0 0\nUUID=bbbb-2222 /boot vfat rw 0 2\n' > "$root/etc/fstab"
: > "$root/boot/vmlinuz-linux-zen"; : > "$root/boot/initramfs-linux-zen.img"
: > "$share/BOOTX64.EFI"

update() { KETCHUP_ROOT="$root" LIMINE_SHARE="$share" "$bin/ketchup-limine" update 2> "$work/err" > /dev/null || { cat "$work/err" >&2; fail "ketchup-limine update failed"; }; }
conf="$root/boot/limine.conf"
live_words='cow_|archiso|copytoram|persist'

# 1. A normal install.
update
grep -q '^/Ketchup (linux-zen)' "$conf"            || fail "no boot entry generated"
grep -q '^editor_enabled: no' "$conf"              || fail "the boot menu editor must be off on an installed system"
! grep -qiE "$live_words" "$conf"                  || fail "live-medium option in a fresh installed menu: $(grep -iE "$live_words" "$conf" | head -n1)"

# 2. Live options planted in the base command line and in boot-extra are dropped, the rest stays.
echo 'root=UUID=aaaa-1111 rw rootflags=subvol=/@ cow_label=KETCHUP_PERSIST archisobasedir=arch' > "$root/etc/kernel/cmdline"
echo 'quiet copytoram=n cow_device=/dev/sdb3 cow_persistent=P archisolabel=KETCHUP_202611 splash' > "$root/etc/ketchup/boot-extra"
update
! grep -qiE "$live_words" "$conf"                  || fail "planted live option reached the menu: $(grep -iE "$live_words" "$conf" | head -n1)"
grep -q 'cmdline: root=UUID=aaaa-1111 rw rootflags=subvol=/@ quiet splash' "$conf" || fail "root= / quiet / splash were lost"
grep -q 'ignoring live-medium kernel options' "$work/err" || fail "dropped options were not reported"

# 3. The installer removes the live-only tool and its document.
grep -q '/usr/local/bin/ketchup-persist' "$bin/ketchup-post-install" || fail "ketchup-post-install does not remove ketchup-persist"
grep -q 'PERSISTENCE.md' "$bin/ketchup-post-install"                 || fail "ketchup-post-install does not remove PERSISTENCE.md"

# 4. cow_label appears only where it is meant to: the persistence tool, the option filter, docs.
unexpected="$(grep -rIl 'cow_label' "$here/archiso/airootfs" | sed "s|$here/archiso/airootfs/||" \
    | grep -vxE 'usr/local/bin/ketchup-(persist|limine)|usr/share/doc/ketchup/PERSISTENCE.md' || true)"
[ -z "$unexpected" ] || fail "cow_label found in unexpected files: $unexpected"

echo "test-installed-boot: OK"
