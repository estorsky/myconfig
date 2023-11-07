#!/bin/bash

MONITOR="$(swaymsg -t get_outputs | jq -c '.[] | select(.focused) | select(.id)' | jq -r -c '.name')"

rofi -monitor "${MONITOR}" -show combi &
