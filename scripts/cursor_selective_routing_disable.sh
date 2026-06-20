#!/bin/bash

set -euo pipefail

TABLE_NAME="${CURSOR_SELECTIVE_ROUTING_TABLE:-myconfig_cursor_route}"
STATE_DIR="${CURSOR_SELECTIVE_ROUTING_STATE_DIR:-/run/myconfig-cursor-routing}"
HELPER_UNIT="${CURSOR_SELECTIVE_ROUTING_HELPER_UNIT:-cursor-routing-helper.service}"
LEGACY_REFRESH_SERVICE="cursor-selective-routing-refresh.service"
LEGACY_REFRESH_TIMER="cursor-selective-routing-refresh.timer"
HELPER_PID_FILE="${STATE_DIR}/helper.pid"

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        exec sudo "$0" "$@"
    fi
}

stop_helper() {
    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "$LEGACY_REFRESH_TIMER" >/dev/null 2>&1 || true
        systemctl stop "$LEGACY_REFRESH_SERVICE" >/dev/null 2>&1 || true
        systemctl disable "$LEGACY_REFRESH_TIMER" >/dev/null 2>&1 || true
    fi

    if command -v systemctl >/dev/null 2>&1; then
        systemctl stop "$HELPER_UNIT" >/dev/null 2>&1 || true
        systemctl reset-failed "$HELPER_UNIT" >/dev/null 2>&1 || true
    fi

    [[ -f "$HELPER_PID_FILE" ]] || return 0

    local pid
    pid="$(<"$HELPER_PID_FILE")"
    if [[ -n "$pid" ]]; then
        kill "$pid" 2>/dev/null || true
    fi
    rm -f "$HELPER_PID_FILE"
}

require_root "$@"

NFT_ONLY=0
for arg in "$@"; do
    if [[ "$arg" == "--nft-only" ]]; then
        NFT_ONLY=1
    fi
done

if [[ "$NFT_ONLY" -eq 1 ]]; then
    nft delete table ip "$TABLE_NAME" 2>/dev/null || true
    exit 0
fi

if command -v systemctl >/dev/null 2>&1 && [[ -f "/etc/systemd/system/${HELPER_UNIT}" ]]; then
    systemctl disable --now "$HELPER_UNIT" >/dev/null 2>&1 || true
fi

stop_helper
nft delete table ip "$TABLE_NAME" 2>/dev/null || true
rm -rf "$STATE_DIR"
