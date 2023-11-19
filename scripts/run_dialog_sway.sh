#!/bin/bash

MONITOR="$(swaymsg -t get_outputs | jq -c '.[] | select(.focused) | select(.id)' | jq -r -c '.name')"

swaymsg input "1:1:AT_Translated_Set_2_keyboard" xkb_switch_layout 0

rofi -monitor "${MONITOR}" -show combi &
