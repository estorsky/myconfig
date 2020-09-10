#!/bin/bash

albert toggle
if xkb-switch --list &> /dev/null; then
    xkb-switch -s us
else
    setxkbmap "us" ",winkeys" "grp:alt_shift_toggle" "ctrl:nocaps"
    sleep 1
    setxkbmap "us,ru" ",winkeys" "grp:alt_shift_toggle" "ctrl:nocaps"
    (gsettings set org.gnome.desktop.input-sources current 0) &
fi

