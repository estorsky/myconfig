#!/bin/bash

MONITOR="$(swaymsg -t get_outputs | jq -c '.[] | select(.focused) | select(.id)' | jq -r -c '.name')"
KEYBOARD="$(swaymsg -t get_inputs | jq -r '.[].identifier' | grep -i keyboard | head -n 1)"

swaymsg input "${KEYBOARD}" xkb_switch_layout 0

rofi -monitor "${MONITOR}" -show combi &
