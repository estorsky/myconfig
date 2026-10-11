#!/bin/bash

set -u

DEVICE_ADDRESS="$(echo "${1:-80:99:E7:FF:97:E2}" | tr '[:lower:]' '[:upper:]')"
DEVICE_OBJECT="/org/bluez/hci0/dev_${DEVICE_ADDRESS//:/_}"
RETRY_DELAY_SEC=0.5
FAST_RETRY_COUNT=20
FALLBACK_RETRY_COUNT=30

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [reconnect_bluetooth] $*" >&2
}

have_required_tools() {
    local tool

    for tool in bluetoothctl busctl jq pw-dump wpctl; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            log_message "Missing required tool: $tool"
            return 1
        fi
    done
}

is_bluetooth_connected() {
    [[ "$(busctl get-property org.bluez "$DEVICE_OBJECT" org.bluez.Device1 Connected 2>/dev/null | awk '{ print $2; exit }')" == "true" ]]
}

pw_objects() {
    pw-dump 2>/dev/null | jq -c --arg address "$DEVICE_ADDRESS" '
        .[] | select(.info.props."api.bluez5.address"? == $address)
    '
}

get_bluetooth_device_id() {
    jq -r 'select(.info.props."media.class"? == "Audio/Device") | .id' <<< "$1" | awk 'NF { print; exit }'
}

get_bluetooth_sink_id() {
    jq -r 'select(.info.props."media.class"? == "Audio/Sink") | .id' <<< "$1" | awk 'NF { print; exit }'
}

get_bluetooth_a2dp_profile_index() {
    jq -r '
        select(.info.props."media.class"? == "Audio/Device")
        | [.info.params.EnumProfile[]? | select(.name | startswith("a2dp-sink"))]
        | (map(select(.name == "a2dp-sink")) + .)[0].index // empty
    ' <<< "$1" | awk 'NF { print; exit }'
}

ensure_bluetooth_audio() {
    local objects
    local device_id
    local profile_index
    local sink_id

    objects="$(pw_objects)"
    [[ -n "$objects" ]] || return 1

    sink_id="$(get_bluetooth_sink_id "$objects")"
    if [[ -z "$sink_id" ]]; then
        device_id="$(get_bluetooth_device_id "$objects")"
        profile_index="$(get_bluetooth_a2dp_profile_index "$objects")"
        if [[ -n "$device_id" && -n "$profile_index" ]]; then
            wpctl set-profile "$device_id" "$profile_index" >/dev/null 2>&1 || true
        fi
        return 1
    fi

    wpctl set-default "$sink_id" >/dev/null 2>&1 || true
    wpctl set-mute "$sink_id" 0 >/dev/null 2>&1 || true
    return 0
}

wait_for_bluetooth_audio() {
    local retries="$1"
    local i

    for ((i = 0; i < retries; i++)); do
        if ensure_bluetooth_audio; then
            return 0
        fi

        sleep "$RETRY_DELAY_SEC"
    done

    return 1
}

have_required_tools || exit 0

log_message "Trying fast audio recovery for $DEVICE_ADDRESS"

if wait_for_bluetooth_audio "$FAST_RETRY_COUNT"; then
    log_message "Bluetooth sink recovered without reconnect"
    exit 0
fi

if ! is_bluetooth_connected; then
    log_message "Device is not reported as connected yet; forcing reconnect anyway"
else
    log_message "Fast recovery failed; forcing Bluetooth reconnect"
fi

bluetoothctl disconnect "$DEVICE_ADDRESS" >/dev/null 2>&1 || true
sleep 1
bluetoothctl connect "$DEVICE_ADDRESS" >/dev/null 2>&1 || true

if wait_for_bluetooth_audio "$FALLBACK_RETRY_COUNT"; then
    log_message "Bluetooth sink recovered after reconnect"
    exit 0
fi

log_message "Bluetooth sink was not detected after reconnect"
exit 1
