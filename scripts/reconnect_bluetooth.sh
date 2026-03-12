#!/bin/bash

set -u

DEVICE_ADDRESS="${1:-80:99:E7:FF:97:E2}"
DEVICE_ID="$(echo "$DEVICE_ADDRESS" | tr '[:upper:]' '[:lower:]' | tr ':' '_')"
FAST_RETRY_DELAY_SEC=0.5
FAST_RETRY_COUNT=12
FALLBACK_RETRY_COUNT=20

is_bluetooth_connected() {
    [[ "$(bluetoothctl info "$DEVICE_ADDRESS" 2>/dev/null | awk '/Connected:/ { print $2; exit }')" == "yes" ]]
}

get_bluetooth_card() {
    pactl list short cards 2>/dev/null | awk -v device_id="$DEVICE_ID" '
        $2 ~ ("bluez_card\\." device_id) { print $2; exit }
    '
}

get_bluetooth_sink() {
    pactl list short sinks 2>/dev/null | awk -v device_id="$DEVICE_ID" '
        $2 ~ ("bluez_output\\." device_id) { print $2; exit }
    '
}

move_existing_streams() {
    local sink="$1"

    pactl list short sink-inputs 2>/dev/null | awk '{ print $1 }' | while read -r input_id; do
        [[ -n "$input_id" ]] || continue
        pactl move-sink-input "$input_id" "$sink" >/dev/null 2>&1 || true
    done
}

ensure_bluetooth_audio() {
    local card
    local sink

    card="$(get_bluetooth_card)"
    if [[ -n "$card" ]]; then
        pactl set-card-profile "$card" a2dp-sink >/dev/null 2>&1 || true
    fi

    sink="$(get_bluetooth_sink)"
    if [[ -n "$sink" ]]; then
        pactl set-default-sink "$sink" >/dev/null 2>&1 || true
        pactl set-sink-mute "$sink" 0 >/dev/null 2>&1 || true
        move_existing_streams "$sink"
        return 0
    fi

    return 1
}

for ((i = 0; i < FAST_RETRY_COUNT; i++)); do
    if ensure_bluetooth_audio; then
        exit 0
    fi

    sleep "$FAST_RETRY_DELAY_SEC"
done

if ! is_bluetooth_connected; then
    exit 1
fi

bluetoothctl disconnect "$DEVICE_ADDRESS" >/dev/null 2>&1 || true
sleep 1
bluetoothctl connect "$DEVICE_ADDRESS" >/dev/null 2>&1 || true

for ((i = 0; i < FALLBACK_RETRY_COUNT; i++)); do
    if ensure_bluetooth_audio; then
        exit 0
    fi

    sleep "$FAST_RETRY_DELAY_SEC"
done

exit 1
