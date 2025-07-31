#!/bin/bash

source ~/myconfig/scripts/common_envs.sh

if ! pgrep -x swaylock &>/dev/null; then

    swaymsg input "${KEYBOARD}" xkb_switch_layout 0

    dunstctl close-all

    playerctl --all-players --no-messages pause

    /usr/local/bin/swaylock \
        --color 000000 \
        --daemonize \
        --screenshots \
        --clock \
        --timestr '%H:%M' \
        --datestr '%a, %d.%m.%y' \
        --indicator \
        --indicator-radius 100 \
        --indicator-thickness 7 \
        --effect-blur 7x5 \
        --effect-vignette 0.5:0.5 \
        --line-color 00000000 \
        --inside-color 00000088 \
        --separator-color 00000000
fi
