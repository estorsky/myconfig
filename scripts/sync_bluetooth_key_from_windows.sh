#!/bin/bash

set -euo pipefail

DEFAULT_DEVICE_ADDRESS="80:99:E7:FF:97:E2"
WINDOWS_HINT_PATH=""
DEVICE_ADDRESS="$DEFAULT_DEVICE_ADDRESS"
CONTROLLER_ADDRESS="${CONTROLLER_ADDRESS:-}"
REGISTRY_READER="${REGISTRY_READER:-}"
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage:
  sync_bluetooth_key_from_windows.sh --windows-path <mounted-windows-path> [options]

Options:
  --windows-path PATH   Any path inside the mounted Windows partition.
  --device MAC          Remote device MAC address. Default: 80:99:E7:FF:97:E2
  --controller MAC      Local Bluetooth controller MAC. Auto-detected by default.
  --registry-reader PATH
                        Path to reged or hivexregedit binary.
  --dry-run             Print the key and target file, but do not modify Linux state.
  --help                Show this help.

Notes:
  - This script currently handles classic Bluetooth LinkKey devices.
  - BLE-only devices use a different key layout and are not updated by this script.
  - Requires either 'reged' (from chntpw) or 'hivexregedit' to read Windows registry hives.
EOF
}

log() {
    echo "[sync_bluetooth_key_from_windows] $*"
}

die() {
    echo "[sync_bluetooth_key_from_windows] $*" >&2
    exit 1
}

normalize_mac_no_colons() {
    echo "$1" | tr '[:upper:]' '[:lower:]' | tr -d ':'
}

discover_windows_root() {
    local current_path="$1"

    [[ -n "$current_path" ]] || return 1

    while [[ "$current_path" != "/" ]]; do
        if [[ -f "$current_path/Windows/System32/config/SYSTEM" ]]; then
            echo "$current_path"
            return 0
        fi

        current_path="$(dirname "$current_path")"
    done

    return 1
}

pick_registry_reader() {
    local candidate

    if [[ -n "$REGISTRY_READER" && -x "$REGISTRY_READER" ]]; then
        echo "$REGISTRY_READER"
        return 0
    fi

    candidate="$(command -v reged 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
        echo "$candidate"
        return 0
    fi

    candidate="$(command -v hivexregedit 2>/dev/null || true)"
    if [[ -n "$candidate" ]]; then
        echo "$candidate"
        return 0
    fi

    return 1
}

export_registry_key() {
    local tool="$1"
    local hive_path="$2"
    local key_path="$3"

    if [[ "$(basename "$tool")" == "reged" ]]; then
        "$tool" -x "$hive_path" 'HKEY_LOCAL_MACHINE\SYSTEM' "$key_path" /dev/stdout
        return 0
    fi

    "$tool" --export --prefix 'HKEY_LOCAL_MACHINE\SYSTEM' "$hive_path" "$key_path"
}

get_current_control_set() {
    local tool="$1"
    local hive_path="$2"
    local current_hex
    local current_num

    current_hex="$(
        export_registry_key "$tool" "$hive_path" '\Select' |
            awk -F: '
                /"Current"=dword:/ { value = $2 }
                END { if (value != "") print value }
            '
    )"

    [[ -n "$current_hex" ]] || die "Не удалось определить CurrentControlSet из Windows hive"
    current_hex="${current_hex//$'\r'/}"

    current_num=$((16#${current_hex}))
    printf 'ControlSet%03d\n' "$current_num"
}

extract_windows_link_key() {
    local tool="$1"
    local hive_path="$2"
    local control_set="$3"
    local controller_id="$4"
    local device_id="$5"
    local registry_dump
    local link_key

    registry_dump="$(
        export_registry_key \
            "$tool" \
            "$hive_path" \
            "\\${control_set}\\Services\\BTHPORT\\Parameters\\Keys\\${controller_id}"
    )"

    link_key="$(
        echo "$registry_dump" |
            awk -v device_id="$device_id" '
                BEGIN {
                    target = "\"" device_id "\"=hex:"
                }
                index(tolower($0), tolower(target)) {
                    sub(/.*=hex:/, "", $0)
                    gsub(/[,\r\n\\[:space:]]/, "", $0)
                    value = toupper($0)
                }
                END { if (value != "") print value }
            '
    )"

    [[ -n "$link_key" ]] || die "Не удалось найти LinkKey для устройства $DEVICE_ADDRESS в Windows registry"
    [[ ${#link_key} -eq 32 ]] || die "Найденный ключ имеет неожиданный размер: $link_key"

    echo "$link_key"
}

detect_controller_address() {
    bluetoothctl show 2>/dev/null | awk '
        /^Controller / { value = $2 }
        END { if (value != "") print value }
    '
}

update_linux_link_key() {
    local info_path="$1"
    local new_key="$2"
    local backup_path="$3"

    sudo cp "$info_path" "$backup_path"

    sudo python3 - "$info_path" "$new_key" <<'PY'
import sys
from pathlib import Path

info_path = Path(sys.argv[1])
new_key = sys.argv[2]

lines = info_path.read_text().splitlines(keepends=True)
inside_link_key = False
section_found = False
key_replaced = False

for idx, line in enumerate(lines):
    stripped = line.strip()
    if stripped.startswith("[") and stripped.endswith("]"):
        inside_link_key = stripped == "[LinkKey]"
        section_found = section_found or inside_link_key
        continue

    if inside_link_key and line.startswith("Key="):
        lines[idx] = f"Key={new_key}\n"
        key_replaced = True
        break

if not section_found:
    raise SystemExit("BlueZ info file does not contain [LinkKey]; BLE-only device or unexpected format")

if not key_replaced:
    raise SystemExit("BlueZ info file does not contain Key= inside [LinkKey]")

info_path.write_text("".join(lines))
PY
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --windows-path)
            WINDOWS_HINT_PATH="${2:-}"
            shift 2
            ;;
        --device)
            DEVICE_ADDRESS="${2:-}"
            shift 2
            ;;
        --controller)
            CONTROLLER_ADDRESS="${2:-}"
            shift 2
            ;;
        --registry-reader)
            REGISTRY_READER="${2:-}"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            die "Неизвестный аргумент: $1"
            ;;
    esac
done

[[ -n "$WINDOWS_HINT_PATH" ]] || die "Нужно передать --windows-path"

WINDOWS_ROOT="$(discover_windows_root "$WINDOWS_HINT_PATH")" || die "Не удалось найти корень Windows от пути: $WINDOWS_HINT_PATH"
SYSTEM_HIVE="$WINDOWS_ROOT/Windows/System32/config/SYSTEM"

REGISTRY_TOOL="$(pick_registry_reader)" || die "Нужен 'reged' или 'hivexregedit' для чтения Windows registry"

if [[ -z "$CONTROLLER_ADDRESS" ]]; then
    CONTROLLER_ADDRESS="$(detect_controller_address)"
fi

[[ -n "$CONTROLLER_ADDRESS" ]] || die "Не удалось определить адрес локального Bluetooth-контроллера"

CONTROLLER_ID="$(normalize_mac_no_colons "$CONTROLLER_ADDRESS")"
DEVICE_ID="$(normalize_mac_no_colons "$DEVICE_ADDRESS")"
CONTROL_SET="$(get_current_control_set "$REGISTRY_TOOL" "$SYSTEM_HIVE")"
WINDOWS_LINK_KEY="$(extract_windows_link_key "$REGISTRY_TOOL" "$SYSTEM_HIVE" "$CONTROL_SET" "$CONTROLLER_ID" "$DEVICE_ID")"

BLUEZ_INFO_PATH="/var/lib/bluetooth/${CONTROLLER_ADDRESS}/${DEVICE_ADDRESS}/info"
BACKUP_PATH="${BLUEZ_INFO_PATH}.bak.$(date +%F_%H-%M-%S)"

log "Windows root: $WINDOWS_ROOT"
log "Registry reader: $REGISTRY_TOOL"
log "Controller: $CONTROLLER_ADDRESS"
log "Device: $DEVICE_ADDRESS"
log "Control set: $CONTROL_SET"
log "BlueZ info: $BLUEZ_INFO_PATH"
log "Windows LinkKey: $WINDOWS_LINK_KEY"

if [[ "$DRY_RUN" -eq 1 ]]; then
    log "Dry-run: Linux файл не изменялся"
    exit 0
fi

sudo test -f "$BLUEZ_INFO_PATH" || die "В Linux не найден файл $BLUEZ_INFO_PATH. Сначала спарь устройство хотя бы один раз в Linux"

update_linux_link_key "$BLUEZ_INFO_PATH" "$WINDOWS_LINK_KEY" "$BACKUP_PATH"
sudo systemctl restart bluetooth

log "LinkKey обновлен, backup сохранен в $BACKUP_PATH"
log "Сервис bluetooth перезапущен"
