#!/bin/bash

set -e

monitors=$(swaymsg -t get_outputs | jq -c '.[] | select(.power == false)' | jq -r -c '.name')

if [[ -n "$monitors" ]]; then
    for monitor in $monitors; do
        swaymsg output "${monitor}" enable
    done
else
    monitors=$(swaymsg -t get_outputs | jq -c '.[] | select(.focused == false) | select(.id)' | jq -r -c '.name')

    for monitor in $monitors; do
        swaymsg output "${monitor}" disable
    done
fi
