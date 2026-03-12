#!/bin/bash

set -u

DEVICE_ADDRESS="${1:-80:99:E7:FF:97:E2}"
RECONNECT_COOLDOWN_SEC=30
DEVICE_PATH="/org/bluez/hci0/dev_${DEVICE_ADDRESS//:/_}"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/bluetooth_audio_monitor.lock"
LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/bluetooth_audio_monitor.log"
last_reconnect_at=0

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

is_connected() {
    [[ "$(bluetoothctl info "$DEVICE_ADDRESS" 2>/dev/null | awk '/Connected:/ { print $2; exit }')" == "yes" ]]
}

handle_connected_event() {
    local now

    now="$(date +%s)"
    if (( now - last_reconnect_at < RECONNECT_COOLDOWN_SEC )); then
        return
    fi

    log_message "Headphones connected, repairing audio routing"

    if "$HOME/myconfig/scripts/reconnect_bluetooth.sh" "$DEVICE_ADDRESS" >> "$LOG_FILE" 2>&1; then
        log_message "Bluetooth audio routing completed"
    else
        log_message "Bluetooth audio routing failed"
    fi

    last_reconnect_at="$now"
}

monitor_bluetooth_events() {
    local in_signal=0
    local connected_key=0
    local line

    stdbuf -oL dbus-monitor --system \
        "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='$DEVICE_PATH'" \
        2>/dev/null |
    while IFS= read -r line; do
        case "$line" in
            *"member=PropertiesChanged"*)
                in_signal=1
                connected_key=0
                ;;
            *'string "Connected"'*)
                if (( in_signal )); then
                    connected_key=1
                fi
                ;;
            *"boolean true"*)
                if (( in_signal && connected_key )); then
                    handle_connected_event
                    in_signal=0
                    connected_key=0
                fi
                ;;
            *"boolean false"*)
                if (( in_signal && connected_key )); then
                    log_message "Headphones disconnected"
                    in_signal=0
                    connected_key=0
                fi
                ;;
            "")
                in_signal=0
                connected_key=0
                ;;
        esac
    done
}

main() {
    log_message "Bluetooth audio monitor started for $DEVICE_ADDRESS via D-Bus events"

    if is_connected; then
        handle_connected_event
    fi

    while true; do
        monitor_bluetooth_events

        log_message "Bluetooth event monitor exited, restarting"
        sleep 1
    done
}

main "$@"
