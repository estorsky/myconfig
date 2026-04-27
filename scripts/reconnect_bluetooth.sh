#!/bin/bash

set -u

DEVICE_ADDRESS="${1:-80:99:E7:FF:97:E2}"
DEVICE_ID="$(echo "$DEVICE_ADDRESS" | tr '[:upper:]' '[:lower:]' | tr ':' '_')"
FAST_RETRY_DELAY_SEC=0.5
FAST_RETRY_COUNT=12
FALLBACK_RETRY_COUNT=20

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [reconnect_bluetooth] $*" >&2
}

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

get_bluetooth_a2dp_profile() {
    local card="$1"

    pactl list cards 2>/dev/null | awk -v card="$card" '
        /^Card #[0-9]+$/ {
            in_card = 0
            in_profiles = 0
        }
        $1 == "Name:" {
            in_card = ($2 == card)
            in_profiles = 0
            next
        }
        in_card && $1 == "Profiles:" {
            in_profiles = 1
            next
        }
        in_card && /^[[:space:]]*Active Profile:/ {
            in_profiles = 0
        }
        in_card && in_profiles {
            line = $0
            sub(/^[[:space:]]+/, "", line)
            split(line, parts, ":")
            profile = parts[1]
            if (profile ~ /^a2dp-sink/ && best == "") {
                best = profile
            }
        }
        END {
            if (best != "") {
                print best
            }
        }
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
    local profile
    local sink

    card="$(get_bluetooth_card)"
    if [[ -n "$card" ]]; then
        profile="$(get_bluetooth_a2dp_profile "$card")"
        if [[ -n "$profile" ]]; then
            pactl set-card-profile "$card" "$profile" >/dev/null 2>&1 || true
        fi
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

log_message "Trying fast audio recovery for $DEVICE_ADDRESS"

for ((i = 0; i < FAST_RETRY_COUNT; i++)); do
    if ensure_bluetooth_audio; then
        log_message "Bluetooth sink recovered without reconnect"
        exit 0
    fi

    sleep "$FAST_RETRY_DELAY_SEC"
done

if ! is_bluetooth_connected; then
    log_message "Device is not reported as connected yet; forcing reconnect anyway"
else
    log_message "Fast recovery failed; forcing Bluetooth reconnect"
fi

bluetoothctl disconnect "$DEVICE_ADDRESS" >/dev/null 2>&1 || true
sleep 1
bluetoothctl connect "$DEVICE_ADDRESS" >/dev/null 2>&1 || true

for ((i = 0; i < FALLBACK_RETRY_COUNT; i++)); do
    if ensure_bluetooth_audio; then
        log_message "Bluetooth sink recovered after reconnect"
        exit 0
    fi

    sleep "$FAST_RETRY_DELAY_SEC"
done

log_message "Bluetooth sink was not detected after reconnect"
exit 1
