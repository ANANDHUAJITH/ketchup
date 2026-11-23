# shellcheck shell=bash
# notify-lib.sh - send a desktop notification to every graphical login session from a
# system service. Services run as root without a D-Bus session, so the notification is
# relayed into each user session bus found through loginctl. Meant to be sourced.
set -u

ketchup_notify_send() {  # ketchup_notify_send "title" "body" [urgency: low|normal|critical] [icon]
    local title="$1" body="$2" urgency="${3:-normal}" icon="${4:-ketchup}"
    local sess runtime sent=0
    # query each session's properties instead of parsing the list-sessions table
    for sess in $(loginctl list-sessions --no-legend 2>/dev/null | awk '{print $1}'); do
        local s_type s_class s_uid s_user s_state
        s_type="$(loginctl show-session "$sess" -p Type --value 2>/dev/null)"
        s_class="$(loginctl show-session "$sess" -p Class --value 2>/dev/null)"
        s_state="$(loginctl show-session "$sess" -p State --value 2>/dev/null)"
        [ "$s_class" = "user" ] || continue
        [ "$s_state" = "active" ] || [ "$s_state" = "online" ] || continue
        case "$s_type" in wayland|x11|mir) ;; *) continue ;; esac
        s_uid="$(loginctl show-session "$sess" -p User --value 2>/dev/null)"
        s_user="$(id -nu "$s_uid" 2>/dev/null)" || continue
        runtime="/run/user/$s_uid"
        [ -S "$runtime/bus" ] || continue
        sudo -u "$s_user" \
            DBUS_SESSION_BUS_ADDRESS="unix:path=$runtime/bus" \
            XDG_RUNTIME_DIR="$runtime" \
            notify-send -u "$urgency" -i "$icon" -a Ketchup "$title" "$body" \
            >/dev/null 2>&1 && sent=1
    done
    # always log, so the message is not lost when nobody is logged in graphically
    logger -t ketchup-notify "$title: $body"
    [ "$sent" = 1 ]
}

# State of notifications already shown. It lives in /var/lib/ketchup so that a
# ketchup-upgrade rollback does not show old announcements again.
KETCHUP_NOTIFY_STATE_DIR="${KETCHUP_NOTIFY_STATE_DIR:-/var/lib/ketchup/notify}"

ketchup_notify_seen() {  # ketchup_notify_seen ID  -> true if already shown
    [ -f "$KETCHUP_NOTIFY_STATE_DIR/$1.seen" ]
}

ketchup_notify_mark_seen() {
    mkdir -p "$KETCHUP_NOTIFY_STATE_DIR"
    : > "$KETCHUP_NOTIFY_STATE_DIR/$1.seen"
    # keep the 50 most recent ids
    find "$KETCHUP_NOTIFY_STATE_DIR" -name '*.seen' -printf '%T@ %p\n' 2>/dev/null \
        | sort -rn | tail -n +51 | cut -d' ' -f2- | xargs -r rm -f
}
