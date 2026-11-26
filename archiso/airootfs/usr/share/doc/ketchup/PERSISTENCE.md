# Persistent live USB

A persistent stick keeps your files, settings and installed programs between reboots. It
uses a second partition (ext4, label `KETCHUP_PERSIST`) in the free space after the ISO on the
same USB stick.

## Set it up

1. Write the ISO to a USB stick that is larger than the ISO (`dd`, balenaEtcher, KDE ISO Image
   Writer). The free space after the ISO is what the persistence partition will use. It needs
   at least 512 MiB.
2. Boot the stick with the normal "Ketchup (zen kernel)" entry.
3. Run `ketchup-persist create`. Add `--size 8G` to use only part of the free space, or
   `--dry-run` to see the plan without writing anything.
4. Reboot and choose **Ketchup persistent** in the boot menu.

`ketchup-persist status` shows whether the current session is persistent and how full the
partition is.

## What is kept

- Everything under `/home/liveuser`, including settings and downloads.
- Changes to the system: installed programs, configuration under `/etc`.

The kernel, initramfs and boot menu come from the ISO and do not change.

## Limits

- The data is not encrypted. Anyone who has the stick can read it.
- Whatever is on the partition is loaded as part of the running system with full privileges.
  The persistent entry uses the partition labelled `KETCHUP_PERSIST` on any attached disk, so
  do not boot it with untrusted USB devices plugged in. `ketchup-persist status` warns when a
  second partition carries the label.
- Persistence exists only on the live USB. The installer copies the clean ISO image, the
  installed system's boot menu is generated from scratch without any persistence option, and
  `ketchup-persist` is removed from the installed system.
- Saved data belongs to one ISO release (it lives in `persistent_<ISO label>`). A new ISO
  starts empty; writing a new ISO to the stick also removes the partition.
- Do not run a full system upgrade on a persistent live stick: the kernel stays at the ISO's
  version while the packages move on. Install a fixed set of programs instead, or install
  Ketchup to disk.
- Use only the **Ketchup persistent** entry with the partition present. If the stick has no
  `KETCHUP_PERSIST` partition, that entry stops at an emergency shell; reboot and pick the
  default entry.
- Ventoy sticks, DVDs and ISOs started from a loop device are not supported. Ventoy has its
  own persistence plugin.

## Erase or remove

- `ketchup-persist reset` erases the saved data and keeps the partition. Boot a
  non-persistent entry first.
- To remove the partition, delete it with GParted or `sudo sfdisk --delete /dev/sdX N`.
