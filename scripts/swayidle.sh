#!/bin/bash

TIMEOUT_LOCK_SEC=$((10 * 60))
TIMEOUT_SCREEN_SEC=$((15 * 60))
TIMEOUT_SLEEP_SEC=$((20 * 60))

pidof -q swayidle && killall -9 swayidle

swayidle -w \
    timeout "${TIMEOUT_LOCK_SEC}" "$HOME/myconfig/scripts/swaylock.sh" \
    timeout "${TIMEOUT_SCREEN_SEC}" "$HOME/myconfig/scripts/sway_dpms.sh off" resume "$HOME/myconfig/scripts/sway_dpms.sh on" \
    timeout "${TIMEOUT_SLEEP_SEC}" "swaymsg 'output * dpms on'; sleep 1; $HOME/myconfig/scripts/suspend.sh" \
    before-sleep "$HOME/myconfig/scripts/swaylock.sh"
