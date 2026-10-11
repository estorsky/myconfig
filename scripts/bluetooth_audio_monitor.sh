#!/bin/bash

set -u

# Order matters: on startup the first reachable device wins.
if (( $# > 0 )); then
    DEVICE_ADDRESSES=("$@")
else
    DEVICE_ADDRESSES=(
        "80:99:E7:FF:97:E2" # WH-1000XM6
        "80:99:E7:FB:3D:40" # WF-1000XM5
    )
fi
RECONNECT_COOLDOWN_SEC=30
AUTOCONNECT_ATTEMPTS=6
AUTOCONNECT_RETRY_DELAY_SEC=10
AUTOCONNECT_TIMEOUT_SEC=15
ADAPTER_PATH="/org/bluez/hci0"
RUNTIME_DIR="${XDG_RUNTIME_DIR:-/tmp}"
LOCK_FILE="$RUNTIME_DIR/bluetooth_audio_monitor.lock"
LOG_FILE="$RUNTIME_DIR/bluetooth_audio_monitor.log"

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

device_path() {
    echo "$ADAPTER_PATH/dev_${1//:/_}"
}

address_from_path() {
    local address

    for address in "${DEVICE_ADDRESSES[@]}"; do
        if [[ "$1" == "$(device_path "$address")" ]]; then
            echo "$address"
            return 0
        fi
    done

    return 1
}

is_connected() {
    [[ "$(busctl get-property org.bluez "$(device_path "$1")" org.bluez.Device1 Connected 2>/dev/null | awk '{ print $2 }')" == "true" ]]
}

is_adapter_powered() {
    [[ "$(busctl get-property org.bluez "$ADAPTER_PATH" org.bluez.Adapter1 Powered 2>/dev/null | awk '{ print $2 }')" == "true" ]]
}

any_device_connected() {
    local address

    for address in "${DEVICE_ADDRESSES[@]}"; do
        is_connected "$address" && return 0
    done

    return 1
}

handle_connected_event() {
    local address="$1"

    (
        exec 9>&-
        exec 8>"$RUNTIME_DIR/bluetooth_audio_monitor.${address//:/_}.lock"
        flock -n 8 || exit 0

        log_message "Headphones $address connected, repairing audio routing"

        if "$HOME/myconfig/scripts/reconnect_bluetooth.sh" "$address" >> "$LOG_FILE" 2>&1; then
            log_message "Bluetooth audio routing completed for $address"
        else
            log_message "Bluetooth audio routing failed for $address"
        fi

        # Keep the lock so that our own reconnect events are ignored.
        sleep "$RECONNECT_COOLDOWN_SEC"
    ) &
}

autoconnect_on_startup() {
    local attempt
    local address

    for ((attempt = 1; attempt <= AUTOCONNECT_ATTEMPTS; attempt++)); do
        sleep 2

        if any_device_connected; then
            return 0
        fi

        if ! is_adapter_powered; then
            log_message "Autoconnect: Bluetooth adapter is not powered yet"
            sleep "$AUTOCONNECT_RETRY_DELAY_SEC"
            continue
        fi

        for address in "${DEVICE_ADDRESSES[@]}"; do
            log_message "Autoconnect attempt $attempt/$AUTOCONNECT_ATTEMPTS: $address"
            timeout "$AUTOCONNECT_TIMEOUT_SEC" bluetoothctl connect "$address" >/dev/null 2>&1 || true

            if is_connected "$address"; then
                log_message "Autoconnect: $address connected"
                return 0
            fi
        done

        sleep "$AUTOCONNECT_RETRY_DELAY_SEC"
    done

    log_message "Autoconnect: no headphones reachable, giving up"
}

monitor_bluetooth_events() {
    local address=""
    local connected_key=0
    local line

    stdbuf -oL dbus-monitor --system \
        "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path_namespace='$ADAPTER_PATH',arg0='org.bluez.Device1'" \
        2>/dev/null |
    while IFS= read -r line; do
        case "$line" in
            *"member=PropertiesChanged"*)
                connected_key=0
                address=""
                if [[ "$line" =~ path=([^;]+) ]]; then
                    address="$(address_from_path "${BASH_REMATCH[1]}")"
                fi
                ;;
            *'string "Connected"'*)
                if [[ -n "$address" ]]; then
                    connected_key=1
                fi
                ;;
            *"boolean true"*)
                if (( connected_key )); then
                    handle_connected_event "$address"
                    connected_key=0
                fi
                ;;
            *"boolean false"*)
                if (( connected_key )); then
                    log_message "Headphones $address disconnected"
                    connected_key=0
                fi
                ;;
        esac
    done
}

main() {
    local address

    log_message "Bluetooth audio monitor started for ${DEVICE_ADDRESSES[*]} via D-Bus events"

    for address in "${DEVICE_ADDRESSES[@]}"; do
        if is_connected "$address"; then
            handle_connected_event "$address"
        fi
    done

    ( exec 9>&-; autoconnect_on_startup ) &

    while true; do
        monitor_bluetooth_events

        log_message "Bluetooth event monitor exited, restarting"
        sleep 1
    done
}

main "$@"
