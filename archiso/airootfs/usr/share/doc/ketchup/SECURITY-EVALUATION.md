# How to evaluate the security of Ketchup

No tool can *prove* an OS is secure. You can only (1) define what you defend against, (2) check the layers
one by one, (3) measure, (4) repeat after every change. This guide gives that process, using tools that ship on the ISO.

## 1. Write the threat model first (10 minutes)

Pick the attackers you care about; the checks that matter follow from them.

| Attacker | Example | Layers that matter |
|---|---|---|
| Thief with your laptop | stolen bag | disk encryption, firmware password, boot menu editing off, Secure Boot |
| Person on the same Wi-Fi | café | no listening services, firewall, SSH keys |
| Malicious website / document | drive-by | browser sandbox (Flatpak/Firefox), updates, user namespaces |
| Malicious package / mirror | supply chain | pacman signatures, repo trust, reproducible builds |
| Malicious local program | compromised app | kernel hardening, sudo/polkit policy, systemd sandboxing |
| Someone altering your ISO | tampered download | checksums + signature, build provenance |

## 2. Run the self-audit (5 minutes)

```bash
sudo ketchup-audit            # boot chain, kernel hardening, accounts, network, packages, services
sudo ketchup-audit --lynis    # adds Lynis' broad hardening audit and its 0-100 "hardening index"
ketchup-audit --json > before.json   # save it, change something, run again, diff
```

`FAIL` = fix now. `WARN` = weakens security, decide. `INFO` = context. Run it on the **installed** system:
the live session is deliberately open (autologin, passwordless sudo, empty passwords) and the audit says so.

## 3. Layer-by-layer checklist (what to verify, and how)

**Boot chain** (`ketchup-audit` → "Boot chain")
* Secure Boot: `mokutil --sb-state` or the audit line. Limine can boot under Secure Boot only if you sign it
  (or use shim); out of the box Ketchup does **not** enable Secure Boot. Be honest about that in your threat model.
* Boot-menu editor must be off on installed systems (`editor_enabled: no`, done by `ketchup-limine`), otherwise `init=/bin/bash` is a root shell.
* Tamper detection: `sudo ketchup-limine pin on` adds BLAKE2b hashes of kernel, initramfs, microcode and enrolls the config hash
  into the EFI loader. Tested: flipping one byte of the kernel makes Limine stop with "Blake2b hash ... does not match".
  Limits: an attacker who can replace the *loader itself* on the ESP, or who can read the disk, is not stopped without Secure Boot + disk encryption.
* Disk encryption: `lsblk -o NAME,TYPE,FSTYPE` shows `crypt`. Without it, physical access = full access.

**Kernel** (`sysctl -a | grep -E 'kptr|dmesg|bpf|ptrace|kexec|protected'`)
* Hardening values are shipped in `/etc/sysctl.d/98-ketchup-hardening.conf`.
* CPU bugs: `grep . /sys/devices/system/cpu/vulnerabilities/*` and keep `intel-ucode`/`amd-ucode` installed (Limine loads them).
* Known CVEs of the installed kernel and packages: `arch-audit`. Update often: `sudo pacman -Syu`.

**Users and privilege**
* `sudo -l`, `grep -r NOPASSWD /etc/sudoers*`, `ls /etc/polkit-1/rules.d`, `passwd -S root` (should be `L`), no `liveuser`.
* SUID inventory: `find /usr -xdev -perm -4000 -ls`. Compare against a fresh install; every extra entry is a finding.

**Network** (from *another* machine too)
* Local: `ss -tulpn`. Remote: `nmap -sS -p- <ip>` from a second host. Expect nothing open on a fresh desktop.
* Firewall: `sudo ufw status` (not installed by default; the audit tells you).

**Services / sandboxing**: `systemd-analyze security` lists every service with an exposure score; harden the worst with drop-ins (`ProtectSystem=strict`, `NoNewPrivileges=yes`...).

**Supply chain** (this is where an OS project is most often weak)
* Every package must be signature-checked. The **live image and the build** trust the CachyOS repo with `SigLevel = Optional TrustAll`
  (`archiso/pacman.conf`, `airootfs/etc/pacman.conf`) because the build container has no CachyOS key. The installer now switches the installed system to
  `Required DatabaseOptional` after the CachyOS keyring is imported; `ketchup-audit` fails if it is still `TrustAll`. To fix the build side too:
  import and locally sign the CachyOS key in `ci-build.sh` (see CachyOS docs for the current key id) and drop `TrustAll`.
* The build downloads files at build time without pinning (`util-iso.sh`: CachyOS mirrorlist from GitHub `master`, old boost from the Arch Linux Archive). Pin by commit/checksum.
* Releases: the workflow publishes `sha256` files. Add a detached signature (`gpg --detach-sign` or `minisign`) with a key whose public half is in the repo/README,
  otherwise a checksum on the same server proves nothing against a compromised server.
* Reproducibility test: build twice with the same `SOURCE_DATE_EPOCH` and compare `sha256sum` of `airootfs.sfs`. If they differ, find out why
  (`diffoscope a.sfs b.sfs`). Ketchup is **not** bit-for-bit reproducible today (live mirrorlist, rolling packages), which is normal for Arch derivatives but means you rely on trusting the CI runner.

## 4. Going deeper (when the basics are green)
* **Lynis** (`--lynis`) maps findings to CIS-style controls. Aim for a rising hardening index, not 100.
* **Kernel config review**: `kernel-hardening-checker` (pip) against `/proc/config.gz`.
* **Fuzzing / exploit testing** of the kernel (syzkaller) or your own code (AFL++, libFuzzer) is where *new* bugs are found; it is expensive and usually out of scope for a distro.
* **Independent review**: ask someone else to read `ketchup-post-install`, `ketchup-limine`, the Calamares configs, and the CI workflow. Most distro compromises are in build/CI, not in the kernel.
* **Learn by attacking**: use `ketchup-lens trace` to see exactly which files, syscalls and memory a program touches; that is also how you spot a binary doing something it should not.

## 5. What this does *not* tell you
A green audit means "no known configuration weaknesses were found". It says nothing about unknown kernel bugs, malicious packages you chose to install,
phishing, or hardware (firmware/Intel ME/USB attacks). Re-run after every major change and keep the JSON outputs to see drift.
