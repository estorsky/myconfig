#!/bin/bash

# TODO: fix pos
swaymsg output eDP-1 position 0 0 mode 2560x1440@144.000Hz
swaymsg output DP-2 position 2880 0 mode 1920x1080@60.000Hz
swaymsg output DP-9 position 2880 0 mode 1920x1080@60.000Hz
swaymsg output DP-10 position 4800 0 mode 1920x1080@60.000Hz
swaymsg output eDP-1 disable
swaymsg output DP-9 enable
swaymsg output DP-10 enable
