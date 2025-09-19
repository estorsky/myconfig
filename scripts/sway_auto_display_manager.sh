#!/bin/bash

MAIN_DISPLAY="eDP-1"
LOG_FILE="/tmp/sway_display_manager.log"

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

check_and_manage_displays() {
    local outputs_info=$(swaymsg -t get_outputs)
    
    local external_enabled=$(
        echo "$outputs_info" | jq -r '.[] | select(.name != "'$MAIN_DISPLAY'") | select(.active == true) | .name'
    )
    
    local main_display_status=$(
        echo "$outputs_info" | jq -r '.[] | select(.name == "'$MAIN_DISPLAY'") | .active'
    )
    
    log_message "Display check: external active = '$external_enabled', main display active = '$main_display_status'"
    
    if [[ -z "$external_enabled" ]]; then
        if [[ "$main_display_status" == "false" ]]; then
            log_message "Enabling main display $MAIN_DISPLAY"
            swaymsg "output '$MAIN_DISPLAY' enable"
        fi
    else
        if [[ "$main_display_status" == "true" ]]; then
            log_message "Disabling main display $MAIN_DISPLAY (external active: $external_enabled)"
            swaymsg "output '$MAIN_DISPLAY' disable"
        fi
    fi
}

log_message "Starting Sway display manager"

while true; do
    log_message "Waiting for Sway event..."
    swaymsg -t subscribe '["output"]' > /dev/null
    log_message "Event received, processing..."
    sleep 2
    check_and_manage_displays
done
