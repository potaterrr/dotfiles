#!/usr/bin/env bash
# ~/.config/waybar/scripts/caffeine.sh
#
# Caffeine mode: keeps the screen awake by holding a logind inhibitor lock.
#
# How it works:
#   - On:  starts a transient systemd user unit (caffeine.service) that runs
#          `systemd-inhibit --what=idle:sleep ...` — an idle:sleep inhibitor
#          lock that hypridle respects (ignore_dbus_inhibit = false).
#   - Off: stops the unit, releasing the lock.
#
# Usage:
#   caffeine.sh toggle    # flip state (used by waybar click + Super+C)
#   caffeine.sh status    # print waybar JSON: {"text","class","tooltip"}
#   caffeine.sh on|off    # explicit set
#
# Hyprland keybind:  bind = $mainMod, C, exec, ~/.config/waybar/scripts/caffeine.sh toggle
# Waybar module:     custom/caffeine  (exec = ... status, on-click = ... toggle)

set -euo pipefail

UNIT="caffeine.service"
NOTIFY_SEND="notify-send"
# Real-time sync: waybar custom modules re-run exec when they receive
# SIGRTMIN+<N> for the N set in their "signal" option (we use 8).
WAYBAR_SIGNAL=8

is_active() {
    # Active iff the transient unit exists and is running.
    systemctl --user is-active --quiet "$UNIT" 2>/dev/null
}

state() {
    if is_active; then
        echo "on"
    else
        echo "off"
    fi
}

notify_waybar() {
    # Nudge waybar to immediately re-run the status script so the icon
    # (💤 / ☕) syncs instantly no matter how the state was changed
    # (keybind, CLI, make toggle, another machine, ...).
    pkill -RTMIN+"$WAYBAR_SIGNAL" -x waybar 2>/dev/null || true
}

notify_on() {
    # Best-effort desktop notification; never fails the toggle.
    command -v "$NOTIFY_SEND" >/dev/null 2>&1 || return 0
    "$NOTIFY_SEND" -a "Caffeine" -u normal -t 2000 -i "coffee" \
        "Caffeine ON" "☕ Screen will stay awake (idle timer paused)" || true
}

notify_off() {
    command -v "$NOTIFY_SEND" >/dev/null 2>&1 || return 0
    "$NOTIFY_SEND" -a "Caffeine" -u normal -t 2000 -i "zzz" \
        "Caffeine OFF" "💤 Normal idle behavior restored" || true
}

cmd_on() {
    if is_active; then
        return 0
    fi
    # Transient unit: systemd-inhibit holds idle+sleep locks while sleep(1) runs.
    systemctl --user start caffeine.service 2>/dev/null || true
    if ! is_active; then
        # Fallback: start via systemd-run (no unit file needed).
        systemd-run --user --unit="$UNIT" --property=Description="Caffeine mode (idle inhibitor)" \
            systemd-inhibit --what="idle:sleep" --who="Caffeine" \
            --why="Keep screen awake" --mode="block" sleep infinity >/dev/null 2>&1 || true
    fi
    notify_on
    notify_waybar
}

cmd_off() {
    if ! is_active; then
        return 0
    fi
    systemctl --user stop "$UNIT" 2>/dev/null || true
    notify_off
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
        # Active: steaming coffee, highlighted via CSS class.
        printf '{"text": " ☕", "class": "active", "tooltip": "Caffeine ON — screen stays awake\\n(click or Super+C to disable)"}'
    else
        # Inactive: sleeping zzz, dimmed via CSS class.
        printf '{"text": " 💤", "class": "inactive", "tooltip": "Caffeine OFF — normal idle timer\\n(click or Super+C to keep awake)"}'
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
