#!/bin/bash

MONITOR="$(swaymsg -t get_outputs | jq -c '.[] | select(.focused) | select(.id)' | jq -r -c '.name')"

source ~/myconfig/scripts/common_envs.sh

swaymsg input "${KEYBOARD}" xkb_switch_layout 0

rofi -monitor "${MONITOR}" -show combi &
