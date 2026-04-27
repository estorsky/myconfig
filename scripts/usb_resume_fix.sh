#!/bin/bash
#
# Скрипт для восстановления USB/DisplayPort после resume из suspend
# Решает проблему "Alt mode has timed out" на AMD Phoenix
#

LOG_TAG="usb_resume_fix"
TARGET_HUB_VENDORS=("05e3" "2109")

log() {
    logger -t "$LOG_TAG" "$1"
    echo "$(date): $1"
}

set_attr_if_writable() {
    local path="$1"
    local value="$2"

    if [ -w "$path" ]; then
        printf '%s\n' "$value" > "$path" 2>/dev/null
    fi
}

is_target_hub() {
    local device_dir="$1"
    local vendor=""
    local device_class=""

    [ -f "${device_dir}/idVendor" ] && vendor=$(< "${device_dir}/idVendor")
    [ -f "${device_dir}/bDeviceClass" ] && device_class=$(< "${device_dir}/bDeviceClass")

    if [ "$device_class" != "09" ]; then
        return 1
    fi

    for target_vendor in "${TARGET_HUB_VENDORS[@]}"; do
        if [ "$vendor" = "$target_vendor" ]; then
            return 0
        fi
    done

    return 1
}

# Устанавливаем power control в "on" для USB контроллеров
fix_pci_power() {
    log "Setting PCI power control to 'on' for USB controllers"
    for dev in /sys/bus/pci/devices/0000:67:00.{0,3,4,5}/power/control; do
        if [ -f "$dev" ]; then
            set_attr_if_writable "$dev" "on" && log "Set $dev to 'on'"
        fi
    done
}

# Убираем autosuspend с hub'ов, через которые приходят USB-устройства дока
fix_usb_hub_power() {
    local device_dir device_name

    log "Setting USB hub power control to 'on'"

    for device_dir in /sys/bus/usb/devices/*; do
        [ -d "$device_dir" ] || continue

        if ! is_target_hub "$device_dir"; then
            continue
        fi

        device_name=$(basename "$device_dir")
        set_attr_if_writable "${device_dir}/power/control" "on" && \
            log "Set ${device_name} power/control to 'on'"
        set_attr_if_writable "${device_dir}/power/wakeup" "enabled" && \
            log "Set ${device_name} power/wakeup to 'enabled'"
        set_attr_if_writable "${device_dir}/authorized" "1" && \
            log "Re-authorized ${device_name}"
    done
}

# Триггер переопределения режима дисплея
trigger_display_rediscovery() {
    log "Triggering display rediscovery"

    # Отправляем сигнал sway на перечитывание outputs если sway запущен
    if pgrep -x sway > /dev/null; then
        sudo -u "${SUDO_USER:-dmitry}" DISPLAY=:0 SWAYSOCK=$(ls /run/user/*/sway-ipc.*.sock 2>/dev/null | head -1) swaymsg reload 2>/dev/null || true
    fi

    # Перезапуск way-displays если работает
    if pgrep -x way-displays > /dev/null; then
        log "Restarting way-displays"
        pkill -HUP way-displays 2>/dev/null || true
    fi
}

main() {
    log "USB resume fix started"

    fix_pci_power
    fix_usb_hub_power

    # Небольшая пауза для стабилизации после пробуждения
    sleep 2

    trigger_display_rediscovery

    log "USB resume fix completed"
}

main "$@"
