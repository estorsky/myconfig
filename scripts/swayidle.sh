#!/bin/bash

TIMEOUT_LOCK_SEC=$((10 * 60))
TIMEOUT_SCREEN_SEC=$((15 * 60))
TIMEOUT_SLEEP_SEC=$((20 * 60))

pidof -q swayidle && killall -9 swayidle

swayidle -w \
    timeout "${TIMEOUT_LOCK_SEC}" 'swaylock.sh' \
    timeout "${TIMEOUT_SCREEN_SEC}" 'swaymsg "output * dpms off"' resume 'swaymsg "output * dpms on"' \
    timeout "${TIMEOUT_SLEEP_SEC}" 'swaymsg "output * dpms on"; sleep 1; suspend.sh' \
    before-sleep 'swaylock.sh'
