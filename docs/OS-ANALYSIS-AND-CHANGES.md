# Ketchup OS - architecture analysis & this pass's changes

## What Ketchup is
An **archiso** profile (not a from-scratch OS): a customized Arch Linux live/install
medium built with `mkarchiso`, running **KDE Plasma (Wayland)** on the **linux-zen**
kernel, installed onto target machines via **Calamares**. Branding, first-boot setup,
a "blue mode" alt-theme, diagnostics and dev-lab tools are layered on top as plain shell
scripts under `archiso/airootfs/usr/local/bin/`, activated through `.desktop` launchers,
systemd units, and pacman hooks (`archiso/airootfs/usr/share/libalpm/hooks/`).

Boot chain: **BIOS → syslinux**, **UEFI → GRUB** (per `profiledef.sh`'s
`bootmodes=('bios.syslinux' 'uefi.grub')`; the `limine/` directory is a template used by
the *installed* system via `ketchup-limine`, not the live ISO itself) → kernel +
initramfs (mkinitcpio, `archiso` hook set) → systemd → autologin on tty1 → Plasma.

## Why it was booting in ~1 minute with no splash
Three real, independent causes, all fixed in this pass:

1. **`COMPRESSION="xz"` for the initramfs** (`airootfs/etc/mkinitcpio.conf.d/archiso.conf`).
   xz has the best compression ratio but is the slowest common codec to *unpack* - and the
   kernel has to fully unpack the initramfs before `init` even starts, every single boot.
   → changed to **`zstd` (level 19, multi-threaded)**: much faster to decompress, size
   difference is marginal since the much larger squashfs rootfs was already zstd.
2. **No splash was ever enabled.** Nothing shipped `plymouth` (not in
   `packages_desktop.x86_64`, no `plymouth` hook in mkinitcpio), and most boot entries
   didn't even pass `quiet`/`splash`, so the console just showed raw kernel log scroll
   for the whole boot.
3. **Boot-menu timeouts ate 8-15s before the kernel even loaded**, and a
   **`systemd-time-wait-sync` unit could block up to 30s** waiting for an NTP server that
   a live/offline medium frequently can't reach - pure dead time with no benefit on a
   live session.

## Changes made in this pass

### Boot speed (target: splash shown almost immediately, desktop in well under 30s on
reasonable hardware - can't be benchmarked from this sandbox, see note below)
- `mkinitcpio.conf.d/archiso.conf`: `COMPRESSION` `xz` → `zstd -19 -T0`.
- `limine.conf.in` timeout `8`→`2`, `efiboot/loader.conf` timeout `15`→`3`,
  `grub/grub.cfg` timeout `10`→`3`. Menus still exist (just hold a key / don't let it
  idle).
- Added `quiet splash loglevel=3` to every **default** boot entry across Limine, GRUB,
  syslinux and the systemd-boot-style loader entry (diagnostic/fallback entries stay
  verbose on purpose - you want to *see* what's happening when troubleshooting).
- Removed `systemd-time-wait-sync.service` from `sysinit.target.wants/` and its override
  - it has no job worth doing on a live medium and could stall early boot.

### Splash screen (uses your GIF)
- Built a Plymouth **script theme** at `usr/share/plymouth/themes/ketchup/` from the 12
  frames of `Animated_KETCHUP_ASCII_Cape_Sequence.gif` (extracted to PNGs), looping at
  roughly the source's ~6fps, centered on black, with a "Booting Ketchup..." caption.
- Added `plymouth` to `packages_desktop.x86_64` and the `plymouth` hook to
  `mkinitcpio.conf.d/archiso.conf`.
- Added a pacman hook (`96-ketchup-plymouth.hook`, same pattern as the existing
  `95-ketchup-limine.hook`) that runs `plymouth-set-default-theme -R ketchup` so the
  theme gets baked into the initramfs automatically whenever `plymouth` is (re)installed
  during the ISO build.

### Wallpapers / "Mythical Blue mode"
- New wallpaper package `usr/share/wallpapers/Ketchup-Blue/` from the new artwork (day
  variant as the primary 1920x1080/3840x2160, night variant alongside it).
- `mythical-blue-ketchup` / `ketchup-blue-core` now also swap the desktop wallpaper to
  it, and `the-legacy-red-ketchup` / a stale restart (`ketchup-blue-reset-check`) now
  restore the original Ketchup wallpaper, not just the icon theme.

### Removed
- **`ketchup-rebrand`** and **`ketchup-logo`** - scripts, `.desktop` launchers, mentions
  in `about.html`, `README.md`, `util-iso.sh`, and their `profiledef.sh` permission
  entries. (The icon literally *named* `ketchup-logo` - the svg/png file used as the
  panel/menu icon - is unrelated and still there; only the two CLI tools are gone.)
- `tools/__pycache__` (stray committed bytecode).
- `archiso/syslinux/splash1.png` (unreferenced by any `.cfg`).

### ASCII art
- Stored at `usr/share/ketchup/ascii/ketchup-logo.txt` and wired up as fastfetch's logo
  (`etc/skel/.config/fastfetch/config.jsonc` now points `logo.source` at that file
  instead of the generic `arch_small` Arch logo).

## Honest caveat on boot timing
This sandbox can edit the profile's source files but can't actually run `mkarchiso`,
boot the resulting ISO in a VM, or stopwatch it - there's no Arch package manager or
bootable-VM access here. The changes above are the standard, well-understood levers for
archiso boot time (initramfs codec, splash wiring, menu timeouts, dropping a blocking
sync unit) and should meaningfully cut real boot time, but you'll want to build the ISO
(`./buildiso.sh` or `ci-build.sh`) and test it in `tools/test-kvm.js` / a real VM to
confirm where it actually lands versus the 10-30s target, especially since real boot
time is dominated by hardware (USB read speed, CPU) at least as much as by this config.

## Suggestions not yet made (would need more direction / testing)
- `pacman-init.service` re-runs `pacman-key --init --populate` every live boot; it's
  already `Nice=19`/`IOSchedulingClass=idle` so it shouldn't block reaching the desktop,
  but on constrained hardware it's still real CPU/IO work for a live-only session - worth
  profiling with `ketchup-doctor` before touching it further.
- The squashfs itself (airootfs rootfs) is already `zstd -19`; a slightly lower level
  (e.g. 15) would speed up *building* the ISO with negligible effect on decompression
  speed at boot, since zstd's decompression cost is fairly level-independent.
