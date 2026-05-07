#!/bin/bash

set -Eeuo pipefail

LOG_TAG="myasus-hook"
SUPPORTED_VENDOR="ASUSTeK COMPUTER INC."
SUPPORTED_PRODUCT_PART="Zephyrus G14"

log() {
    logger -t "$LOG_TAG" -- "$*"
}

on_error() {
    local line_no="$1"
    local command="$2"
    local exit_code="$3"

    log "hook error line=${line_no} exit=${exit_code} command=${command}"
}

trap 'on_error "${LINENO}" "${BASH_COMMAND}" "$?"' ERR

read_sysfs() {
    local path="$1"

    [ -r "$path" ] || return 0
    head -n 1 "$path"
}

host_vendor() {
    read_sysfs /sys/class/dmi/id/sys_vendor
}

host_product() {
    read_sysfs /sys/class/dmi/id/product_name
}

is_supported_host() {
    local vendor product

    vendor="$(host_vendor)"
    product="$(host_product)"

    [[ "$vendor" == "$SUPPORTED_VENDOR" ]] && [[ "$product" == *"$SUPPORTED_PRODUCT_PART"* ]]
}

power_supply_summary() {
    local supply name online status type
    local -a entries=()

    for supply in /sys/class/power_supply/*; do
        [ -d "$supply" ] || continue

        name="$(basename "$supply")"
        type="$(read_sysfs "${supply}/type")"
        online="$(read_sysfs "${supply}/online")"
        status="$(read_sysfs "${supply}/status")"

        entries+=("${name}:type=${type:-unknown},online=${online:-na},status=${status:-unknown}")
    done

    local IFS=';'
    printf '%s\n' "${entries[*]}"
}

get_profile() {
    asusctl profile get 2>/dev/null | sed -n 's/^Active profile: //p'
}

ensure_integrated_mode() {
    local current_mode="" pending_action="" pending_mode="" output=""

    command -v supergfxctl >/dev/null 2>&1 || return 0

    if ! systemctl is-active --quiet supergfxd.service 2>/dev/null; then
        log "supergfxd is not active, skip integrated enforcement"
        return 0
    fi

    current_mode="$(supergfxctl -g 2>/dev/null || true)"

    if [ "$current_mode" != "Integrated" ]; then
        output="$(supergfxctl -m Integrated 2>&1 || true)"
        [ -n "$output" ] && log "supergfxctl set Integrated: ${output//$'\n'/ | }"
    fi

    pending_action="$(supergfxctl -p 2>/dev/null || true)"
    pending_mode="$(supergfxctl -P 2>/dev/null || true)"

    if [ -n "$pending_action" ] && [ "$pending_action" != "No action required" ]; then
        log "pending_action=${pending_action} pending_mode=${pending_mode:-unknown}"
    fi
}

log_status() {
    local source_label="$1"
    local profile="" gfx_mode="" pending_action="" pending_mode="" dgpu_disable="" gpu_mux="" power_summary=""

    profile="$(get_profile 2>/dev/null || true)"
    gfx_mode="$(supergfxctl -g 2>/dev/null || true)"
    pending_action="$(supergfxctl -p 2>/dev/null || true)"
    pending_mode="$(supergfxctl -P 2>/dev/null || true)"
    dgpu_disable="$(read_sysfs /sys/devices/platform/asus-nb-wmi/dgpu_disable)"
    gpu_mux="$(read_sysfs /sys/devices/platform/asus-nb-wmi/gpu_mux_mode)"
    power_summary="$(power_supply_summary)"

    log "source=${source_label} profile=${profile:-unknown} supergfx_mode=${gfx_mode:-unknown} pending_action=${pending_action:-unknown} pending_mode=${pending_mode:-unknown} dgpu_disable=${dgpu_disable:-unknown} gpu_mux_mode=${gpu_mux:-unknown} power_supplies=${power_summary:-unknown}"
}

main() {
    local source_label="${1:-unknown}"

    is_supported_host || exit 0

    log "hook start source=${source_label}"
    ensure_integrated_mode
    log_status "$source_label"
    log "hook done source=${source_label}"
}

main "$@"
