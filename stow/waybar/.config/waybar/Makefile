# Makefile for the Caffeine waybar module
#
# Caffeine keeps the screen awake by holding a logind idle:sleep inhibitor
# lock (respected by hypridle). Toggle via the waybar icon (💤 / ☕) or Super+C.
#
# Targets:
#   make install    - enable everything (script perms, systemd unit, reloads)
#   make uninstall  - remove caffeine from the running session
#   make toggle     - flip caffeine on/off (same as clicking the icon)
#   make on / off   - explicitly enable / disable
#   make status     - show whether caffeine is active

SCRIPT   := $(HOME)/.config/waybar/scripts/caffeine.sh
UNIT     := caffeine.service

.PHONY: install uninstall toggle on off status help

help:
	@echo "Caffeine module targets: install | uninstall | toggle | on | off | status"

install:
	@chmod +x "$(SCRIPT)"
	@systemctl --user daemon-reload
	@pkill -x waybar 2>/dev/null || true
	@sleep 0.5
	@hyprctl dispatch exec waybar >/dev/null 2>&1 || nohup waybar >/dev/null 2>&1 &
	@hyprctl reload >/dev/null 2>&1 || true
	@echo "Caffeine installed: waybar icon + Super+C keybind are live."

uninstall:
	@systemctl --user stop $(UNIT) 2>/dev/null || true
	@systemctl --user reset-failed 2>/dev/null || true
	@echo "Caffeine stopped for this session."
	@echo "Note: remove the custom/caffeine module + Super+C bind from configs to fully remove."

toggle:
	@bash "$(SCRIPT)" toggle

on:
	@bash "$(SCRIPT)" on

off:
	@bash "$(SCRIPT)" off

status:
	@bash "$(SCRIPT)" status; echo
	@systemctl --user is-active $(UNIT) 2>/dev/null || true
