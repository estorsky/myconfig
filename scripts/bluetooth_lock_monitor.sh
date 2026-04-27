#!/bin/bash

set -u

DEVICE_ADDRESS="${BLUETOOTH_LOCK_DEVICE_ADDRESS:-${1:-}}"
CONFIGURED_DEVICE_ADDRESS="$DEVICE_ADDRESS"
DEVICE_NAME="${BLUETOOTH_LOCK_DEVICE_NAME:-Pixel 8}"
MIN_RSSI="${BLUETOOTH_LOCK_MIN_RSSI:--85}"
MIN_RSSI_RAW="${BLUETOOTH_LOCK_MIN_RSSI_RAW:-}"
MIN_RSSI_PERCENT="${BLUETOOTH_LOCK_MIN_RSSI_PERCENT:-35}"
MAX_TPL_RAW="${BLUETOOTH_LOCK_MAX_TPL_RAW:--6}"
ARM_TPL_RAW="${BLUETOOTH_LOCK_ARM_TPL_RAW:--4}"
MANUAL_UNLOCK_RELOCK_TPL_RAW="${BLUETOOTH_LOCK_MANUAL_UNLOCK_RELOCK_TPL_RAW:-}"
CHECK_INTERVAL_SEC="${BLUETOOTH_LOCK_CHECK_INTERVAL_SEC:-1}"
BAD_CHECKS_TO_LOCK="${BLUETOOTH_LOCK_BAD_CHECKS_TO_LOCK:-1}"
LOCK_COOLDOWN_SEC="${BLUETOOTH_LOCK_COOLDOWN_SEC:-0}"
STARTUP_GRACE_SEC="${BLUETOOTH_LOCK_STARTUP_GRACE_SEC:-3}"
ENABLE_SCAN="${BLUETOOTH_LOCK_ENABLE_SCAN:-true}"
RSSI_SCAN_INTERVAL_SEC="${BLUETOOTH_LOCK_RSSI_SCAN_INTERVAL_SEC:-20}"
RSSI_SCAN_DURATION_SEC="${BLUETOOTH_LOCK_RSSI_SCAN_DURATION_SEC:-3}"
MISSING_GRACE_SEC="${BLUETOOTH_LOCK_MISSING_GRACE_SEC:-35}"
DEBUG="${BLUETOOTH_LOCK_DEBUG:-false}"
LOCK_SCRIPT="${BLUETOOTH_LOCK_SCRIPT:-$HOME/myconfig/scripts/swaylock.sh}"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/bluetooth_lock_monitor.lock"
ARMED_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/bluetooth_lock_monitor.armed"
LOG_FILE="${XDG_RUNTIME_DIR:-/tmp}/bluetooth_lock_monitor.log"

bad_checks=0
last_lock_at=0
last_scan_at=0
last_seen_at=0
armed=false
locked_for_current_bad_state=false
last_status=""
scan_started=false
started_at="$(date +%s)"

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

log_status() {
    local status="$1"
    local message="$2"

    if [[ "$status" != "$last_status" ]]; then
        log_message "$message"
        last_status="$status"
    fi
}

log_debug() {
    [[ "$DEBUG" == "true" ]] || return 0

    log_message "DEBUG: $*"
}

load_armed_state() {
    local saved_address
    local saved_at
    local now

    [[ -f "$ARMED_STATE_FILE" ]] || return 0

    saved_address="$(awk -F= '$1 == "address" { print $2; exit }' "$ARMED_STATE_FILE" 2>/dev/null || true)"
    saved_at="$(awk -F= '$1 == "last_seen_at" { print $2; exit }' "$ARMED_STATE_FILE" 2>/dev/null || true)"
    now="$(date +%s)"

    [[ -n "$saved_address" && "$saved_address" == "${DEVICE_ADDRESS:-$saved_address}" ]] || return 0
    is_integer "$saved_at" || return 0

    if (( now - saved_at <= 12 * 60 * 60 )); then
        DEVICE_ADDRESS="$saved_address"
        last_seen_at="$saved_at"
        armed=true
        log_message "Restored armed state for $DEVICE_ADDRESS; last seen $((now - saved_at))s ago"
    fi
}

save_armed_state() {
    local seen_at="$1"

    [[ -n "$DEVICE_ADDRESS" ]] || return 0

    {
        printf 'address=%s\n' "$DEVICE_ADDRESS"
        printf 'last_seen_at=%s\n' "$seen_at"
    } > "$ARMED_STATE_FILE"
}

usage() {
    cat <<EOF
Usage: $(basename "$0") [device-mac]

Locks the current Sway session when the phone is disconnected or its Bluetooth
RSSI is lower than the configured threshold.

Environment:
  BLUETOOTH_LOCK_DEVICE_ADDRESS      Device MAC address. Overrides [device-mac].
  BLUETOOTH_LOCK_DEVICE_NAME         Device name to auto-detect. Default: Pixel 8
  BLUETOOTH_LOCK_MIN_RSSI            Weak signal threshold. Default: -85
  BLUETOOTH_LOCK_MIN_RSSI_RAW        Weak conn_info RSSI threshold. Default: disabled
  BLUETOOTH_LOCK_MIN_RSSI_PERCENT    Weak signal threshold for blueman conn_info. Default: 35
  BLUETOOTH_LOCK_MAX_TPL_RAW         High transmit power threshold. Default: -6
  BLUETOOTH_LOCK_ARM_TPL_RAW         TPL close enough to arm/reset the monitor. Default: -4
  BLUETOOTH_LOCK_MANUAL_UNLOCK_RELOCK_TPL_RAW
                                      Relock after manual unlock at this stronger bad TPL. Default: disabled
  BLUETOOTH_LOCK_BAD_CHECKS_TO_LOCK  Consecutive bad checks before lock. Default: 1
  BLUETOOTH_LOCK_CHECK_INTERVAL_SEC  Check interval. Default: 1
  BLUETOOTH_LOCK_ENABLE_SCAN         Scan for unpaired devices. Default: true
  BLUETOOTH_LOCK_MISSING_GRACE_SEC   Missing-device grace after last good sighting. Default: 35
  BLUETOOTH_LOCK_DEBUG               Log every monitor decision. Default: false
EOF
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    usage
    exit 0
fi

find_device_address() {
    list_dbus_devices | while read -r device_path; do
        printf 'Device %s %s\n' "$(dbus_device_address "$device_path")" "$(dbus_device_name "$device_path")"
    done
    bluetoothctl devices Paired 2>/dev/null
    bluetoothctl devices 2>/dev/null
}

is_bluetooth_powered() {
    [[ "$(dbus_adapter_powered)" == "true" ]] || \
        [[ "$(bluetoothctl show 2>/dev/null | awk '/^[[:space:]]*Powered:/ { print $2; exit }')" == "yes" ]]
}

dbus_adapter_path() {
    busctl tree org.bluez 2>/dev/null | awk '
        match($0, /\/org\/bluez\/hci[0-9]+$/) {
            print substr($0, RSTART, RLENGTH)
            exit
        }
    '
}

dbus_adapter_powered() {
    local adapter_path

    adapter_path="$(dbus_adapter_path)"
    [[ -n "$adapter_path" ]] || return 0

    busctl get-property org.bluez "$adapter_path" org.bluez.Adapter1 Powered 2>/dev/null | awk '{ print $2 }'
}

list_dbus_devices() {
    busctl tree org.bluez 2>/dev/null | awk '
        match($0, /\/org\/bluez\/hci[0-9]+\/dev_([0-9A-F]{2}_){5}[0-9A-F]{2}/) {
            print substr($0, RSTART, RLENGTH)
        }
    '
}

dbus_string_property() {
    local device_path="$1"
    local property_name="$2"

    busctl get-property org.bluez "$device_path" org.bluez.Device1 "$property_name" 2>/dev/null | awk '
        {
            sub(/^[^"]*"/, "")
            sub(/"$/, "")
            print
        }
    '
}

dbus_bool_property() {
    local device_path="$1"
    local property_name="$2"

    busctl get-property org.bluez "$device_path" org.bluez.Device1 "$property_name" 2>/dev/null | awk '{ print $2 }'
}

dbus_int_property() {
    local device_path="$1"
    local property_name="$2"

    busctl get-property org.bluez "$device_path" org.bluez.Device1 "$property_name" 2>/dev/null | awk '{ print $2 }'
}

dbus_device_address() {
    dbus_string_property "$1" Address
}

dbus_device_name() {
    local device_path="$1"
    local name

    name="$(dbus_string_property "$device_path" Alias)"
    if [[ -z "$name" ]]; then
        name="$(dbus_string_property "$device_path" Name)"
    fi

    printf '%s\n' "$name"
}

dbus_device_path_by_address() {
    local adapter_path
    local address="$1"

    adapter_path="$(dbus_adapter_path)"
    if [[ -z "$adapter_path" ]]; then
        adapter_path="/org/bluez/hci0"
    fi

    printf '%s/dev_%s\n' "$adapter_path" "${address//:/_}"
}

adapter_name() {
    basename "$(dbus_adapter_path)"
}

get_conn_info_levels() {
    local address="$1"
    local adapter="$2"

    [[ -n "$address" && -n "$adapter" ]] || return 0

    python3 - "$address" "$adapter" <<'PY' 2>/dev/null || true
import sys

try:
    from _blueman import ConnInfoReadError, conn_info
except Exception:
    sys.exit(0)

address, adapter = sys.argv[1], sys.argv[2]
cinfo = conn_info(address, adapter)

try:
    cinfo.init()
except ConnInfoReadError:
    sys.exit(0)

def read_value(method):
    try:
        return method()
    except ConnInfoReadError:
        return None

try:
    rssi = read_value(cinfo.get_rssi)
    tpl = read_value(cinfo.get_tpl)
finally:
    cinfo.deinit()

def percent(value):
    if value is None:
        return ""
    return max(50 + float(value) / 127 * 50, 10)

if rssi is not None:
    print(f"rssi_raw={rssi}")
    print(f"rssi_percent={percent(rssi):.0f}")
if tpl is not None:
    print(f"tpl_raw={tpl}")
    print(f"tpl_percent={percent(tpl):.0f}")
PY
}

detect_device_address() {
    find_device_address | awk -v name="$DEVICE_NAME" '
        $1 == "Device" {
            address = $2
            display_name = $0
            sub(/^Device[[:space:]]+[^[:space:]]+[[:space:]]+/, "", display_name)
            if (display_name == name) {
                print address
                exit
            }
        }
    '
}

start_rssi_scan_if_due() {
    local adapter_path
    local now

    scan_started=false
    [[ "$ENABLE_SCAN" == "true" ]] || return 0

    now="$(date +%s)"
    if (( now - last_scan_at < RSSI_SCAN_INTERVAL_SEC )); then
        log_debug "skip discovery scan: last_scan=${last_scan_at} interval=${RSSI_SCAN_INTERVAL_SEC}s"
        return 0
    fi

    adapter_path="$(dbus_adapter_path)"
    if [[ -n "$adapter_path" ]]; then
        log_debug "start discovery scan via D-Bus for ${RSSI_SCAN_DURATION_SEC}s"
        busctl call org.bluez "$adapter_path" org.bluez.Adapter1 StartDiscovery >/dev/null 2>&1 || true
    else
        log_debug "start discovery scan via bluetoothctl for ${RSSI_SCAN_DURATION_SEC}s"
        bluetoothctl scan on >/dev/null 2>&1 || true
    fi

    sleep "$RSSI_SCAN_DURATION_SEC"
    scan_started=true
    last_scan_at="$now"
}

stop_rssi_scan_if_started() {
    local adapter_path

    [[ "$scan_started" == true ]] || return 0

    adapter_path="$(dbus_adapter_path)"
    if [[ -n "$adapter_path" ]]; then
        busctl call org.bluez "$adapter_path" org.bluez.Adapter1 StopDiscovery >/dev/null 2>&1 || true
    else
        bluetoothctl scan off >/dev/null 2>&1 || true
    fi

    scan_started=false
    log_debug "stop discovery scan"
}

get_connected_state() {
    awk '/^[[:space:]]*Connected:/ { print $2; exit }'
}

get_rssi() {
    awk '/^[[:space:]]*RSSI:/ { print $2; exit }'
}

is_integer() {
    [[ "$1" =~ ^-?[0-9]+$ ]]
}

is_connected_state() {
    [[ "$1" == "yes" || "$1" == "true" ]]
}

lock_screen() {
    local reason="$1"
    local now

    now="$(date +%s)"
    if (( now - started_at < STARTUP_GRACE_SEC )); then
        log_message "Skipping lock during startup grace: $reason"
        return 1
    fi

    if (( now - last_lock_at < LOCK_COOLDOWN_SEC )); then
        log_message "Skipping lock during cooldown: $reason"
        return 1
    fi

    if pgrep -x swaylock >/dev/null 2>&1; then
        log_message "Screen is already locked; not claiming this lock: $reason"
        return 0
    fi

    log_message "Locking screen: $reason"
    if "$LOCK_SCRIPT" >/dev/null 2>>"$LOG_FILE"; then
        last_lock_at="$now"
        return 0
    else
        log_message "Lock command failed"
        return 1
    fi
}

check_phone() {
    local device_path info connected rssi reason now missing_for bluetoothctl_rssi
    local conn_info_levels rssi_raw rssi_percent tpl_raw tpl_percent rssi_source

    rssi_raw=""
    rssi_percent=""
    tpl_raw=""
    tpl_percent=""

    if ! is_bluetooth_powered; then
        bad_checks=0
        armed=false
        locked_for_current_bad_state=false
        DEVICE_ADDRESS="$CONFIGURED_DEVICE_ADDRESS"
        last_seen_at=0
        rm -f "$ARMED_STATE_FILE"
        log_status "bluetooth-off" "Bluetooth is off or no default controller is available; monitor is idle"
        return 0
    fi

    start_rssi_scan_if_due

    if [[ -z "$DEVICE_ADDRESS" ]]; then
        DEVICE_ADDRESS="$(detect_device_address)"
        if [[ -n "$DEVICE_ADDRESS" ]]; then
            log_message "Detected $DEVICE_NAME as $DEVICE_ADDRESS"
        else
            bad_checks=0
            armed=false
            locked_for_current_bad_state=false
            stop_rssi_scan_if_started
            log_status "not-found" "Device '$DEVICE_NAME' is not known or visible; monitor is idle"
            return 0
        fi
    fi

    device_path="$(dbus_device_path_by_address "$DEVICE_ADDRESS")"
    connected="$(dbus_bool_property "$device_path" Connected)"
    rssi="$(dbus_int_property "$device_path" RSSI)"
    rssi_source="dbus"

    info="$(bluetoothctl info "$DEVICE_ADDRESS" 2>/dev/null || true)"

    if [[ -z "$connected" ]]; then
        connected="$(printf '%s\n' "$info" | get_connected_state)"
        rssi="$(printf '%s\n' "$info" | get_rssi)"
        rssi_source="bluetoothctl"
    elif ! is_integer "$rssi"; then
        bluetoothctl_rssi="$(printf '%s\n' "$info" | get_rssi)"
        if is_integer "$bluetoothctl_rssi"; then
            rssi="$bluetoothctl_rssi"
            rssi_source="bluetoothctl"
        fi
    fi

    if is_connected_state "$connected"; then
        conn_info_levels="$(get_conn_info_levels "$DEVICE_ADDRESS" "$(adapter_name)")"
        rssi_raw="$(printf '%s\n' "$conn_info_levels" | awk -F= '$1 == "rssi_raw" { print $2; exit }')"
        rssi_percent="$(printf '%s\n' "$conn_info_levels" | awk -F= '$1 == "rssi_percent" { print $2; exit }')"
        tpl_raw="$(printf '%s\n' "$conn_info_levels" | awk -F= '$1 == "tpl_raw" { print $2; exit }')"
        tpl_percent="$(printf '%s\n' "$conn_info_levels" | awk -F= '$1 == "tpl_percent" { print $2; exit }')"
        if is_integer "$rssi_percent"; then
            rssi_source="conn_info"
        fi
    fi

    stop_rssi_scan_if_started
    now="$(date +%s)"
    log_debug "state: address=$DEVICE_ADDRESS connected=${connected:-unknown} rssi=${rssi:-unknown} rssi_percent=${rssi_percent:-unknown} rssi_raw=${rssi_raw:-unknown} tpl_percent=${tpl_percent:-unknown} tpl_raw=${tpl_raw:-unknown} rssi_source=$rssi_source armed=$armed locked_for_current_bad_state=$locked_for_current_bad_state bad_checks=$bad_checks last_seen_at=$last_seen_at"

    if is_integer "$ARM_TPL_RAW" && is_integer "$tpl_raw" && (( tpl_raw <= ARM_TPL_RAW )); then
        armed=true
        locked_for_current_bad_state=false
        last_seen_at="$now"
        save_armed_state "$now"
        log_status "healthy" "$DEVICE_NAME ($DEVICE_ADDRESS) is close enough: connected=$connected tpl_raw=$tpl_raw"
        if (( bad_checks > 0 )); then
            log_message "Phone is back in range: connected=$connected tpl_raw=$tpl_raw"
        fi
        bad_checks=0
        return 0
    elif is_integer "$tpl_raw" && (( tpl_raw >= MAX_TPL_RAW )); then
        reason="$DEVICE_NAME ($DEVICE_ADDRESS) high transmit power raw ${tpl_raw} >= ${MAX_TPL_RAW}"
    elif is_integer "$MIN_RSSI_RAW" && is_integer "$rssi_raw" && (( rssi_raw <= MIN_RSSI_RAW )); then
        reason="$DEVICE_NAME ($DEVICE_ADDRESS) weak RSSI raw ${rssi_raw} <= ${MIN_RSSI_RAW}"
    elif is_integer "$rssi_percent" && (( rssi_percent < MIN_RSSI_PERCENT )); then
        reason="$DEVICE_NAME ($DEVICE_ADDRESS) weak RSSI ${rssi_percent}% < ${MIN_RSSI_PERCENT}%"
    elif is_integer "$rssi" && (( rssi < MIN_RSSI )); then
        reason="$DEVICE_NAME ($DEVICE_ADDRESS) weak RSSI ${rssi} dBm < ${MIN_RSSI} dBm"
    elif ! is_connected_state "$connected" && ! is_integer "$rssi"; then
        if [[ "$armed" != true ]]; then
            bad_checks=0
            log_status "not-armed-disconnected" "$DEVICE_NAME ($DEVICE_ADDRESS) is not connected or visible yet; waiting before arming"
            return 0
        fi

        missing_for=$((now - last_seen_at))
        if (( missing_for < MISSING_GRACE_SEC )); then
            bad_checks=0
            log_status "missing-grace" "$DEVICE_NAME ($DEVICE_ADDRESS) is missing for ${missing_for}s; waiting for the next scan"
            return 0
        fi

        if [[ "$locked_for_current_bad_state" == true ]]; then
            bad_checks=0
            log_status "missing-locked" "$DEVICE_NAME ($DEVICE_ADDRESS) is still missing; already locked for this bad state"
            return 0
        fi

        reason="$DEVICE_NAME ($DEVICE_ADDRESS) missing for ${missing_for}s"
    else
        armed=true
        locked_for_current_bad_state=false
        last_seen_at="$now"
        save_armed_state "$now"
        log_status "healthy" "$DEVICE_NAME ($DEVICE_ADDRESS) is in range: connected=$connected rssi=${rssi:-unknown}"
        if (( bad_checks > 0 )); then
            log_message "Phone is back in range: connected=$connected rssi=${rssi:-unknown}"
        fi
        bad_checks=0
        return 0
    fi

    if [[ "$armed" != true ]]; then
        bad_checks=0
        log_status "not-armed-bad-signal" "$DEVICE_NAME ($DEVICE_ADDRESS) has a bad signal before the first healthy sighting; waiting before arming"
        return 0
    fi

    if [[ "$locked_for_current_bad_state" == true ]]; then
        if [[ -n "$MANUAL_UNLOCK_RELOCK_TPL_RAW" ]] && \
            ! pgrep -x swaylock >/dev/null 2>&1 && \
            is_integer "$MANUAL_UNLOCK_RELOCK_TPL_RAW" && \
            is_integer "$tpl_raw" && \
            (( tpl_raw >= MANUAL_UNLOCK_RELOCK_TPL_RAW )); then
            log_message "Treating strong signal loss after manual unlock as a new bad episode: tpl_raw ${tpl_raw} >= ${MANUAL_UNLOCK_RELOCK_TPL_RAW}"
            locked_for_current_bad_state=false
        else
            bad_checks=0
            log_status "bad-state-locked" "$DEVICE_NAME ($DEVICE_ADDRESS) is still in a bad state; already locked for this episode"
            return 0
        fi
    fi

    ((bad_checks++))
    log_message "Bad phone check ${bad_checks}/${BAD_CHECKS_TO_LOCK}: $reason"

    if (( bad_checks >= BAD_CHECKS_TO_LOCK )); then
        if lock_screen "$reason"; then
            locked_for_current_bad_state=true
        fi
        bad_checks=0
    fi
}

main() {
    log_message "Bluetooth lock monitor started: name='$DEVICE_NAME' address='${DEVICE_ADDRESS:-auto}' max_tpl_raw=$MAX_TPL_RAW arm_tpl_raw=$ARM_TPL_RAW manual_unlock_relock_tpl_raw=$MANUAL_UNLOCK_RELOCK_TPL_RAW min_rssi_raw=$MIN_RSSI_RAW bad_checks=$BAD_CHECKS_TO_LOCK check_interval=${CHECK_INTERVAL_SEC}s debug=$DEBUG lock_script='$LOCK_SCRIPT'"

    while true; do
        check_phone
        sleep "$CHECK_INTERVAL_SEC"
    done
}

main "$@"
