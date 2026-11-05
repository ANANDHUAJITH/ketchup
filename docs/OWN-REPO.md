# Should Ketchup use its own package repo instead of CachyOS?

## What Ketchup actually takes from CachyOS today
Read from `archiso/packages_desktop.x86_64`, `archiso/pacman.conf`, `util-iso.sh`:

| Package / file | Why | Replaceable? |
|---|---|---|
| `cachyos-calamares-next` | the installer (Calamares built against current Arch libs) | hard: you must rebuild Calamares whenever boost/Qt/KF6 change (`util-iso.sh` already needs a boost workaround) |
| `ananicy-cpp`, `cachyos-ananicy-rules` | process priority rules | easy: small PKGBUILDs (or drop; the rules are data) |
| `paru` | AUR helper | easy: it is an AUR package; build it yourself or ship `yay`/`paru-bin` |
| `cachyos-keyring`, `cachyos-mirrorlist`, `cachyos-v3-mirrorlist` | trust + mirrors for the above | disappear if the rest is replaced |
| `[cachyos-v3]` repos (opt-in via `ketchup-v3`) | x86-64-v3 optimised builds | **not realistically**: needs a build farm re-compiling thousands of packages |

The kernel (`linux-zen`), KDE, firmware and everything else already come from Arch `core/extra`. So the dependency is small.

## Is your own repo "better"?
* **Better for trust and control: yes.** Fewer third-party signers, you decide what ships, no surprise rebuilds, and you can sign everything with your key.
* **Better for performance: no.** There is no speed gain from a repo by itself. Only CachyOS' v3/v4 rebuilds and its patched kernels give that, and you are not using the kernels.
* **Better for effort and stability: no.** You become responsible for rebuilding on every soname/ABI bump, keeping a signing key safe, hosting, and CVE response. The boost breakage already in this project is a preview.

## Recommended path (cheapest first)
1. **Now:** keep CachyOS for the five packages above, but stop trusting it blindly: key-pin it in the build (`SigLevel = Required`), pin the mirrorlist fetch, and let `ketchup-audit` check the installed system (done for the installed side).
2. **Next, and the best value:** create a tiny `[ketchup]` repo containing **your own tools** as packages (`ketchup-tools`: everything in `usr/local/bin/ketchup-*`, `ketchup-branding`: logos/wallpaper/icons, `ketchup-lens`). Today these are baked into the ISO and **never update** after install; as packages they update with `pacman -Syu`. Build with a GitHub Action in a clean Arch container (`makepkg`), sign with `repo-add --sign`, publish to GitHub Releases/Pages.
3. **Later (optional):** replace `ananicy-*`/`paru` with your own builds, then decide about Calamares (own fork vs another installer). Only then drop `[cachyos]` entirely.

## Minimal repo mechanics (when you do step 2)
```bash
# in a clean Arch container, per package:  makepkg -s --sign
repo-add --sign ketchup.db.tar.zst *.pkg.tar.zst           # creates the signed database
# users add to /etc/pacman.conf:
#   [ketchup]
#   SigLevel = Required DatabaseOptional
#   Server = https://<your-pages-or-release-url>/$arch
# and trust your key once:  sudo pacman-key --add ketchup.gpg && sudo pacman-key --lsign-key <KEYID>
```
Keep the signing key offline or in a GitHub Actions secret with environment protection; a stolen key is a stolen distro.
