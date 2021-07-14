#!/bin/bash

# albert toggle

rofi -show combi &

if xkb-switch --list &> /dev/null; then
    xkb-switch -s us
else
    setxkbmap -layout us -option grp:alt_shift_toggle -option ctrl:nocaps
    sleep 1
    setxkbmap -layout us,ru -option grp:alt_shift_toggle -option ctrl:nocaps
    (gsettings set org.gnome.desktop.input-sources current 0) &
fi

