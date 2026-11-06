<p align="center">
  <img src="archiso/airootfs/usr/share/ketchup/logo.svg" width="420" alt="Ketchup">
</p>

# Ketchup

Ketchup is an Arch-based desktop operating system with KDE Plasma, the `linux-zen` kernel, and a collection of tools for everyday use and hands-on learning. It is based on the [CachyOS Live ISO](https://github.com/CachyOS/CachyOS-Live-ISO), with its own desktop look, boot experience, and preinstalled software.

## Desktop and apps

Ketchup boots into KDE Plasma with a dark Breeze theme, a tomato accent, and custom Ketchup artwork. The live system can be installed with the Calamares installer, including when offline. New installations use Btrfs with zstd compression and subvolumes by default.

The system includes Flatpak with Flathub and Discover for desktop applications, along with Podman and Distrobox for running containerized Linux environments. A set of command-line tools is included, such as `bat`, `fd`, `ripgrep`, `zoxide`, `yazi`, Helix, and Zellij.

## System features

- **Limine boot menu** for BIOS and UEFI systems.
- **`linux-zen` kernel** and desktop-oriented system defaults.
- **Memory and storage management** with zram using zstd compression and scheduled weekly `fstrim`.
- **Performance and responsiveness settings**, including BBR, I/O scheduler rules, `ananicy-cpp`, `scx_lavd`, and `systemd-oomd`.
- **Rootless containers** using Podman and Distrobox.
- **A focused live environment** that does not copy the full image into RAM at startup.

## Learn how Linux works

Ketchup includes **Ketchup Lens**, a set of interactive tools for exploring computer and operating-system concepts.

- Run `ketchup-lens sim` to step through KetchupVM, a small simulated computer with registers, memory, caches, disk, system calls, interrupts, and scheduling.
- Run `ketchup-lens trace -- ./program` to examine a real program’s system calls and runtime behavior in an interactive HTML report.
- Run `ketchup-lens hw` to see an overview of the machine’s CPU, cache, memory, and storage.
- Run `ketchup-lens samples` to build small C programs for experiments.

Ketchup also includes networking and OS-internals labs, with tools such as `gdb`, `strace`, `perf`, `bpftrace`, and `tcpdump`. The study notes are available at `/usr/share/doc/ketchup/STUDY.md`.

## Included Ketchup tools

- **`ketchup-doctor`** gathers diagnostic information, including boot time, memory, network status, and IRQ errors, into `~/ketchup-diagnostics.txt`.
- **`ketchup-mirrors`** checks Arch mirrors and ranks them by speed.
- **`ketchup-v3`** lets you opt in to x86-64-v3 packages from the CachyOS repositories. Run `ketchup-v3 off` to undo the change.
- **`ketchup-apps-location`** lets you choose where Flatpak or Distrobox apps are stored. For example: `ketchup-apps-location flatpak /mnt/bigdrive`. Pacman packages remain in system locations.
- **`ketchup-logo`** changes the Ketchup logo used in the desktop and installer. Open **Change Ketchup Logo** from the app menu, or use `ketchup-logo set my.svg`. Use `sudo ketchup-logo set my.svg` to change it for all users, and `ketchup-logo reset` to restore the default.
- **Blue mode** switches the panel logo and icon theme to blue for the current login. Run `mythical-blue-ketchup` to enter and `the-legacy-red-ketchup` to switch back. While active, `ketchup-blue-vault` manages an encrypted `~/BlueVault` folder, and `ketchup-blue-apps` manages a disposable Distrobox environment. Both tools include commands to remove their data.

## IRQ troubleshooting

If startup reports `irq 27: nobody cared` or a device stops working, run `ketchup-irqfix 27` to see information about the device, driver, and kernel messages. The live boot menu also includes an **IRQ troubleshooting** submenu.

Ketchup's boot entries include `noirqdebug`, which prevents the kernel from disabling an interrupt line. This can help a system get past certain IRQ-related problems, but it does not fix the underlying driver or firmware issue. Use the diagnostic options to investigate the affected hardware.

## Security

Run `sudo ketchup-audit` to check the boot chain, kernel settings, accounts, network configuration, package signatures, and services. Add `--lynis` to include Lynis checks or `--json` to produce JSON output.

For the project’s security notes and known limitations, see [`SECURITY-EVALUATION.md`](archiso/airootfs/usr/share/doc/ketchup/SECURITY-EVALUATION.md).

## Credits and license

Ketchup is licensed under GPL-3.0 and is based on the CachyOS Live ISO profile and Arch Linux `archiso`. Ketchup is an independent project and is not affiliated with CachyOS.
