# Updates, release trains and announcements

This document covers `ketchup-upgrade`, `ketchup-notifyd`, the `[ketchup-pkg]` pacman
repository, and what to publish in
[`ANANDHUAJITH/ketchup`](https://github.com/ANANDHUAJITH/ketchup) and
[`ANANDHUAJITH/ketchup-pkg`](https://github.com/ANANDHUAJITH/ketchup-pkg) to drive them.

## How updates work

Ketchup is a rolling release (plain `pacman -Syu`) that is also stamped with a release
train number (`26.0`, `27.0`, ...). `ketchup-upgrade` applies updates the way openSUSE's
`transactional-update` does, using pacman and Limine:

1. Take a writable Btrfs snapshot of the running root (`@` to `@snapshots/ketchup-<timestamp>/snapshot`).
2. `arch-chroot` into the snapshot only and run the update there: sync the repositories
   (including `[ketchup-pkg]`), `pacman -Su`, `mkinitcpio -P`.
3. Point the snapshot's `/etc/fstab` and kernel command line at itself and regenerate the
   boot menu from inside the snapshot (`ketchup-limine update`), so the running system's
   boot configuration is not modified.
4. On the next reboot the machine starts the new snapshot. The previous root, together with
   the previous kernel and initramfs (backed up to `/boot/ketchup/rollback/<timestamp>/`),
   stays bootable as the "Ketchup (previous system)" entry.
5. `ketchup-boot-guard` runs before and after the graphical session. If a fresh update
   fails to reach a working login three boots in a row, it restores the previous system
   and reboots.

Root stays writable between updates; the safety comes from updates never being applied to
the system that is currently running. If any step fails, the snapshot is discarded and the
running system is unchanged.

Only `@` is snapshotted and rolled back. `/home`, `/var/log`, `/var/cache`, `/.snapshots`
(`@snapshots`) and `/var/lib/ketchup` (`@ketchup-assets`, personal wallpapers and branding)
are separate subvolumes, so neither an upgrade nor a rollback touches them.

### Live sessions

A live medium has no disk to snapshot. `ketchup-upgrade` detects `/run/archiso` and offers a
plain `pacman -Syu` of the live overlay, which does not survive a reboot. `ketchup-notifyd`
and `ketchup-upgrade check` work the same live and installed.

## The `ketchup-pkg` repository

`[ketchup-pkg]` is enabled in `/etc/pacman.conf` and points at
`https://ANANDHUAJITH.github.io/ketchup-pkg/$arch`. To use another URL, change
`KETCHUP_PKG_REPO_NAME` in `/etc/ketchup/upgrade.conf` and the `Server=` line together.
The repository must be reachable, otherwise the database sync reports an error.

To publish a repository with GitHub Pages:

```bash
repo-add ketchup-pkg.db.tar.gz *.pkg.tar.zst
# commit the database, the .files archive and the packages to the gh-pages branch
# (or a /docs folder) with GitHub Pages enabled
```

Packages too large for Pages can be published as GitHub release assets; point `Server=` at
`https://github.com/ANANDHUAJITH/ketchup-pkg/releases/download/<tag>`. Pacman only needs
static URLs for the database and the packages.

### `release.yml`

Published at `https://raw.githubusercontent.com/ANANDHUAJITH/ketchup-pkg/main/release.yml`
(`KETCHUP_RELEASE_MANIFEST_URL`):

```yaml
version: "27.0"
codename: "Habanero"
```

`ketchup-upgrade` compares the major number with `KETCHUP_VERSION` in `/etc/ketchup-release`.
A routine update applies silently. When the major number increases, it prints a banner
(unless `--auto`) and, once the update succeeds, writes the new version and codename to
`/etc/ketchup-release` and `/etc/os-release`.

## Announcements: `notif.yml`

`ketchup-notify.timer` runs `ketchup-notifyd` 5 minutes after boot and every 30 minutes
afterwards. It fetches
`https://raw.githubusercontent.com/ANANDHUAJITH/ketchup/main/notif.yml` and shows a desktop
notification when the `id` differs from the last one shown:

```yaml
id: 2026-11-15-01        # required; change it to show a new announcement
title: "Ketchup 27.0 is here"
message: "Run 'ketchup-upgrade' to move up."
level: info              # info | warning | critical (notify-send urgency)
url: "https://github.com/ANANDHUAJITH/ketchup/releases"   # optional
```

The notification is relayed from the root service into every graphical session bus and is
also written to the journal.

## Commands

| Command | Description |
|---|---|
| `ketchup-version` | Show the release train and the last upgrade time |
| `ketchup-upgrade` | Apply the next update atomically (asks before a major-train change) |
| `ketchup-upgrade check` | Look for updates and a new train; install nothing |
| `ketchup-upgrade --auto` | Non-interactive mode, used by the timer |
| `ketchup-upgrade --reboot` | Apply, then reboot into the new snapshot |
| `ketchup-upgrade history` | List the kept root snapshots |
| `ketchup-upgrade prune` | Delete snapshots beyond `KETCHUP_KEEP_SNAPSHOTS` |
| `ketchup-rollback` | Make a rollback permanent (run it after booting the previous system) |

If an update does not boot, `ketchup-boot-guard` rolls back after three attempts, or you can
select "Ketchup (previous system)" in the boot menu. Configuration is in
`/etc/ketchup/upgrade.conf`.
