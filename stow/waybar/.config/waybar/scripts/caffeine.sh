#!/usr/bin/env bash
# ~/.config/waybar/scripts/caffeine.sh
#
# Caffeine mode: keeps the screen awake by holding a logind inhibitor lock.
# The inhibitor runs as the caffeine.service user unit, which hypridle respects
# (ignore_dbus_inhibit = false).
#
# Usage:
#   caffeine.sh toggle    # flip state (waybar click + Super+C)
#   caffeine.sh status    # waybar JSON: {"text","class","tooltip"}
#   caffeine.sh on|off    # explicit set

set -euo pipefail

UNIT="caffeine.service"
# Waybar re-runs a custom module's exec on SIGRTMIN+<signal>; config uses 8.
WAYBAR_SIGNAL=8

is_active() {
    systemctl --user is-active --quiet "$UNIT" 2>/dev/null
}

notify_waybar() {
    pkill -RTMIN+"$WAYBAR_SIGNAL" -x waybar 2>/dev/null || true
}

notify() {
    local icon="$1" title="$2" body="$3"
    command -v notify-send >/dev/null 2>&1 || return 0
    notify-send -a "Caffeine" -u normal -t 2000 -i "$icon" "$title" "$body" || true
}

cmd_on() {
    if ! is_active; then
        if ! systemctl --user start "$UNIT" 2>/dev/null; then
            notify dialog-error "Caffeine" "Could not start $UNIT"
            return 1
        fi
        notify coffee "Caffeine ON" "󰅶 Screen will stay awake (idle timer paused)"
    fi
    notify_waybar
}

cmd_off() {
    if is_active; then
        systemctl --user stop "$UNIT" 2>/dev/null || true
        notify zzz "Caffeine OFF" "󰾪 Normal idle behavior restored"
    fi
    notify_waybar
}

cmd_toggle() {
    if is_active; then
        cmd_off
    else
        cmd_on
    fi
}

cmd_status() {
    if is_active; then
        printf '{"text": "󰅶", "class": "active", "tooltip": "Caffeine ON — screen stays awake\\n(click or Super+C to disable)"}'
    else
        printf '{"text": "󰾪", "class": "inactive", "tooltip": "Caffeine OFF — normal idle timer\\n(click or Super+C to keep awake)"}'
    fi
}

case "${1:-status}" in
    toggle) cmd_toggle ;;
    on)     cmd_on ;;
    off)    cmd_off ;;
    status) cmd_status ;;
    *)
        echo "Usage: $0 {toggle|on|off|status}" >&2
        exit 1
        ;;
esac
