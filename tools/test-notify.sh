#!/bin/bash
# The notification id comes from a downloaded file and becomes a file name: it must not be
# able to write outside the state directory.
set -euo pipefail
here="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
fail() { echo "FAIL: $*" >&2; exit 1; }

export KETCHUP_NOTIFY_STATE_DIR="$work/state/notify"
# shellcheck source=/dev/null
source "$here/archiso/airootfs/usr/lib/ketchup/notify-lib.sh"

for bad in "" ".." "../evil" "a/b" "/etc/x" ".hidden" "with space" "$(printf 'a\nb')" "$(printf 'x%.0s' {1..80})"; do
    ketchup_notify_mark_seen "$bad" && fail "accepted id: '$bad'"
done
[ -z "$(find "$work" -type f)" ] || fail "an invalid id created a file: $(find "$work" -type f)"

for good in "2026-11-release" "notice_1" "v1.2.3"; do
    ketchup_notify_mark_seen "$good" || fail "rejected id: $good"
    ketchup_notify_seen "$good"      || fail "id not remembered: $good"
done
ketchup_notify_seen "never-shown" && fail "unseen id reported as seen"
echo "test-notify: OK"
