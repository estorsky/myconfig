#!/bin/bash

set -e

enabled_not_focused=$(swaymsg -t get_outputs | jq -c '.[] | select(.focused == false) | select(.power == true)' | jq -r -c '.name')

if [[ -n "$enabled_not_focused" ]]; then
    for monitor in $enabled_not_focused; do
        swaymsg output "${monitor}" disable
    done
else
    all_monitors=$(swaymsg -t get_outputs | jq -r -c '.[] | .name')
    for monitor in $all_monitors; do
        swaymsg output "${monitor}" enable
    done
fi
