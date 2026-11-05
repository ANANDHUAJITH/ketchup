# Boot failure: "Failed to mount '/dev/disk/by-label/KETCHUP_*'"

## Symptom

Boot drops to the archiso initramfs recovery shell (`[rootfs ~]#`) with:

```
mount: /run/archiso/bootmnt:
wrong fs type, bad option, bad superblock
ERROR: Failed to mount '/dev/disk/by-label/KETCHUP_<date>'
Falling back to interactive prompt
```

## Cause

ISOs built before this fix had a bug in `make_limine_iso()` (`util-iso.sh`): the
`xorriso` call passed `-hfsplus -apm-block-size 2048` to also stamp an Apple
Partition Map / HFS+ wrapper onto the hybrid USB image, for old PowerPC Mac
"Startup Disk" boot. xorriso has no separate label option for that HFS+
volume - it always reuses whatever `-volid` was given to the ISO9660
filesystem. The result: **two** filesystems on the same USB share the label
`KETCHUP_<date>`:

```
/dev/sdb    ISO9660   KETCHUP_<date>   <- the real boot medium
/dev/sdb3   HFS+      KETCHUP_<date>   <- bogus, same label
```

`/dev/disk/by-label/KETCHUP_<date>` is a symlink to whichever device the
kernel registered last, which can be the HFS+ partition instead of the
ISO9660 volume. archiso then tries to mount HFS+ as if it were the live
ISO9660 filesystem and fails.

**Fixed** by removing `-hfsplus -apm-block-size 2048` from the xorriso
invocation - the ISO/USB now only ever has one filesystem carrying the
label, so the collision can't happen. BIOS and UEFI (El Torito) boot are
unaffected; this only drops support for pre-2006 PowerPC Mac firmware, which
can't run this OS anyway.

## Fix for your install medium

**If you haven't flashed your USB yet:** rebuild the ISO from this version
and flash that one. Nothing else to do.

**If you already have an affected USB and need to boot it right now**,
recover without reflashing:

```sh
# at the [rootfs ~]# prompt

# 1. point the label at the real ISO9660 volume instead of the HFS+ one
#    (replace sdb / KETCHUP_<date> with what blkid shows you)
blkid                                   # find your USB device and its real label
ln -sf ../../sdb /dev/disk/by-label/KETCHUP_<date>
ls -l /dev/disk/by-label/KETCHUP_<date> # should now show -> ../../sdb

# 2. mount it where archiso expects it
mkdir -p /run/archiso/bootmnt
mount -t iso9660 -o ro /dev/sdb /run/archiso/bootmnt
ls /run/archiso/bootmnt                 # expect: EFI arch boot boot.catalog

# 3. resume boot
exit
```

This gets you booted, but the USB itself still has the duplicate-label
defect. Re-flash it with an ISO built from this fixed version as soon as
convenient - the workaround above does not survive a reboot (the kernel may
re-resolve the label to the wrong partition again next time).
