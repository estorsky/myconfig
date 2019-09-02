#!/bin/sh

TIME=$((60 - $(date +%M)))m
sleep $TIME
while true; do
    notify-send watch "go work!"; sleep 45m
    notify-send watch "relax dude"; sleep 15m
done
#DISPLAY=:0.0 notify-send -i atom "Watch" "`date +%H:%M`"
