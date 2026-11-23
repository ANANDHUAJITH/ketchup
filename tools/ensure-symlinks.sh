#!/bin/bash
#
# Make sure every file in the live image that has to be a symlink IS a symlink.
#
#   tools/ensure-symlinks.sh [DIR]            create / repair them (what util-iso.sh runs)
#   tools/ensure-symlinks.sh --check [DIR]    only report; exit 1 if anything is wrong
#
# DIR defaults to archiso/airootfs next to this script.
#
# systemd honours enablement links (<target>.wants/<unit>, default.target,
# display-manager.service, dbus-org.*.service) only when they are real symlinks.
# Zip archives made on Windows, GitHub web uploads and git with core.symlinks=false turn
# them into plain copies or drop them. The manifest below is the single source of truth and
# the build recreates every link from it.
#
# Entry format:  <path relative to airootfs>|<symlink target>
# A relative target (../x) must exist next to the link; an absolute one points
# at a unit shipped by a package, so it is resolved inside the built image.

set -u

mode=apply
root=""
for a in "$@"; do
    case "$a" in
        --check)   mode=check ;;
        -h|--help) sed -n '3,9p' "$0"; exit 0 ;;
        *)         root="$a" ;;
    esac
done
[ -n "$root" ] || root="$(cd "$(dirname "$0")/.." && pwd)/archiso/airootfs"
[ -d "$root" ] || { echo "ensure-symlinks: no such directory: $root" >&2; exit 2; }

SYSD=etc/systemd/system
UNITS=/usr/lib/systemd/system

MANIFEST=(
    # --- boot: graphical.target pulls in display-manager.service, which is greetd
    "$SYSD/default.target|$UNITS/graphical.target"
    "$SYSD/display-manager.service|$UNITS/greetd.service"

    # --- networking: what `systemctl enable NetworkManager` creates
    "$SYSD/multi-user.target.wants/NetworkManager.service|$UNITS/NetworkManager.service"
    "$SYSD/dbus-org.freedesktop.nm-dispatcher.service|$UNITS/NetworkManager-dispatcher.service"

    # --- Ketchup's own units (the unit files live in $SYSD itself)
    "$SYSD/multi-user.target.wants/pacman-init.service|../pacman-init.service"
    "$SYSD/sysinit.target.wants/ketchup-boot-guard-pre.service|../ketchup-boot-guard-pre.service"
    "$SYSD/graphical.target.wants/ketchup-boot-guard-post.service|../ketchup-boot-guard-post.service"
    "$SYSD/timers.target.wants/ketchup-notify.timer|../ketchup-notify.timer"
    "$SYSD/timers.target.wants/ketchup-upgrade-check.timer|../ketchup-upgrade-check.timer"

    # --- packaged timers
    "$SYSD/timers.target.wants/fstrim.timer|$UNITS/fstrim.timer"
)

bad=0 fixed=0
declare -A in_manifest=()
for entry in "${MANIFEST[@]}"; do in_manifest["$root/${entry%%|*}"]=1; done

say() { printf '%s\n' "$*"; }

for entry in "${MANIFEST[@]}"; do
    link="${entry%%|*}"
    target="${entry#*|}"
    path="$root/$link"

    if [ -L "$path" ] && [ "$(readlink "$path")" = "$target" ]; then
        :
    elif [ "$mode" = check ]; then
        if [ -L "$path" ]; then
            say "WRONG TARGET  $link -> $(readlink "$path")  (want $target)"
        elif [ -e "$path" ]; then
            say "NOT A SYMLINK $link  (regular file; want -> $target)"
        else
            say "MISSING       $link  (want -> $target)"
        fi
        bad=1
        continue
    else
        mkdir -p "$(dirname "$path")"
        rm -f "$path"
        ln -s "$target" "$path"
        say "symlink  $link -> $target"
        fixed=$((fixed + 1))
    fi

    # a relative link must point at a file that exists in the tree
    case "$target" in
        /*) ;;
        *)  if [ ! -e "$(dirname "$path")/$target" ]; then
                say "DANGLING      $link -> $target  (the unit it points to is missing from the tree)"
                bad=1
            fi ;;
    esac
done

# Safety net for links added later and forgotten above: any regular file sitting in
# a *.wants / *.requires directory is a flattened link. Rebuild it from the unit
# of the same name (next to it in $SYSD, else the packaged one).
while IFS= read -r -d '' f; do
    [ -n "${in_manifest[$f]:-}" ] && continue     # already handled (and reported) above
    rel="${f#"$root"/}"
    unit="$(basename "$f")"
    if [ -f "$root/$SYSD/$unit" ]; then t="../$unit"; else t="$UNITS/$unit"; fi
    if [ "$mode" = check ]; then
        say "NOT A SYMLINK $rel  (regular file in a .wants/.requires dir; want -> $t)"
        bad=1
    else
        rm -f "$f"
        ln -s "$t" "$f"
        say "symlink  $rel -> $t  (flattened copy replaced)"
        fixed=$((fixed + 1))
    fi
done < <(find "$root/$SYSD" \( -path '*.wants/*' -o -path '*.requires/*' \) -type f -print0 2>/dev/null)

if [ "$mode" = check ]; then
    if [ "$bad" = 0 ]; then
        say "ensure-symlinks: all ${#MANIFEST[@]} required symlinks are in place"
    else
        say "ensure-symlinks: problems found - run tools/ensure-symlinks.sh to repair"
    fi
    exit "$bad"
fi
say "ensure-symlinks: ${#MANIFEST[@]} required symlinks verified, $fixed (re)created"
exit "$bad"
