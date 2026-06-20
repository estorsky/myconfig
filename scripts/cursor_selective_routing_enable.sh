#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TABLE_NAME="${CURSOR_SELECTIVE_ROUTING_TABLE:-myconfig_cursor_route}"
CHAIN_NAME="${CURSOR_SELECTIVE_ROUTING_CHAIN:-output}"
STATE_DIR="${CURSOR_SELECTIVE_ROUTING_STATE_DIR:-/run/myconfig-cursor-routing}"
HELPER_PORT="${CURSOR_SELECTIVE_ROUTING_HELPER_PORT:-12335}"
SOCKS_HOST="${CURSOR_SELECTIVE_ROUTING_SOCKS_HOST:-127.0.0.1}"
SOCKS_PORT="${CURSOR_SELECTIVE_ROUTING_SOCKS_PORT:-12334}"
HELPER_UNIT="${CURSOR_SELECTIVE_ROUTING_HELPER_UNIT:-cursor-routing-helper.service}"
ROUTE_GROUP="${CURSOR_SELECTIVE_ROUTING_GROUP:-cursorroute}"
LEGACY_REFRESH_SERVICE="cursor-selective-routing-refresh.service"
LEGACY_REFRESH_TIMER="cursor-selective-routing-refresh.timer"
HELPER_PID_FILE="${STATE_DIR}/helper.pid"
HELPER_LOG_FILE="${STATE_DIR}/helper.log"

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        exec sudo "$0" "$@"
    fi
}

target_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        printf '%s\n' "${SUDO_USER}"
        return 0
    fi

    logname 2>/dev/null || id -un
}

route_gid() {
    getent group "$ROUTE_GROUP" | cut -d: -f3 | head -n 1
}

ensure_route_group() {
    local user_name
    user_name="$(target_user)"

    if ! getent group "$ROUTE_GROUP" >/dev/null 2>&1; then
        groupadd --system "$ROUTE_GROUP"
    fi

    if [[ -n "$user_name" && "$user_name" != "root" ]]; then
        usermod -a -G "$ROUTE_GROUP" "$user_name"
    fi
}

stop_legacy_refresh_units() {
    if ! command -v systemctl >/dev/null 2>&1; then
        return 0
    fi

    systemctl stop "$LEGACY_REFRESH_TIMER" >/dev/null 2>&1 || true
    systemctl stop "$LEGACY_REFRESH_SERVICE" >/dev/null 2>&1 || true
    systemctl disable "$LEGACY_REFRESH_TIMER" >/dev/null 2>&1 || true
}

helper_running() {
    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$HELPER_UNIT"; then
        return 0
    fi

    [[ -f "$HELPER_PID_FILE" ]] || return 1
    local pid
    pid="$(<"$HELPER_PID_FILE")"
    [[ -n "$pid" ]] || return 1
    kill -0 "$pid" 2>/dev/null
}

ensure_nftables_objects() {
    local gid_value
    gid_value="$(route_gid)"

    if [[ -z "$gid_value" ]]; then
        echo "failed to resolve routing group id for $ROUTE_GROUP" >&2
        exit 1
    fi

    nft list table ip "$TABLE_NAME" >/dev/null 2>&1 || nft add table ip "$TABLE_NAME"
    nft list chain ip "$TABLE_NAME" "$CHAIN_NAME" >/dev/null 2>&1 || \
        nft "add chain ip ${TABLE_NAME} ${CHAIN_NAME} { type nat hook output priority dstnat; policy accept; }"
    nft flush chain ip "$TABLE_NAME" "$CHAIN_NAME"
    nft add rule ip "$TABLE_NAME" "$CHAIN_NAME" \
        counter \
        meta skgid "$gid_value" tcp dport '{' 80, 443 '}' \
        redirect to :"$HELPER_PORT" \
        comment "cursor_selective_routing"
}

start_helper() {
    mkdir -p "$STATE_DIR"
    : > "$HELPER_LOG_FILE"

    if helper_running; then
        return 0
    fi

    if command -v systemd-run >/dev/null 2>&1; then
        systemctl stop "$HELPER_UNIT" >/dev/null 2>&1 || true
        systemctl reset-failed "$HELPER_UNIT" >/dev/null 2>&1 || true

        systemd-run \
            --quiet \
            --unit="$HELPER_UNIT" \
            --collect \
            /bin/sh -lc \
            "exec python3 \"$SCRIPT_DIR/cursor_selective_transparent_proxy.py\" \
                --listen-host 127.0.0.1 \
                --listen-port \"$HELPER_PORT\" \
                --socks-host \"$SOCKS_HOST\" \
                --socks-port \"$SOCKS_PORT\" \
                >>\"$HELPER_LOG_FILE\" 2>&1"

        systemctl show -p MainPID --value "$HELPER_UNIT" > "$HELPER_PID_FILE"
    else
        setsid python3 "$SCRIPT_DIR/cursor_selective_transparent_proxy.py" \
            --listen-host 127.0.0.1 \
            --listen-port "$HELPER_PORT" \
            --socks-host "$SOCKS_HOST" \
            --socks-port "$SOCKS_PORT" \
            >>"$HELPER_LOG_FILE" 2>&1 < /dev/null &

        echo "$!" > "$HELPER_PID_FILE"
    fi

    sleep 0.2

    if ! helper_running; then
        echo "failed to start cursor selective routing helper" >&2
        exit 1
    fi
}

print_status() {
    local pid=""

    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet "$HELPER_UNIT"; then
        pid="$(systemctl show -p MainPID --value "$HELPER_UNIT" 2>/dev/null || true)"
    elif [[ -f "$HELPER_PID_FILE" ]]; then
        pid="$(<"$HELPER_PID_FILE")"
    fi

    echo "table: $TABLE_NAME"
    echo "route_group: $ROUTE_GROUP"
    echo "route_gid: $(route_gid)"
    echo "helper_port: $HELPER_PORT"
    echo "socks_proxy: ${SOCKS_HOST}:${SOCKS_PORT}"

    if helper_running; then
        echo "helper_state: running${pid:+ pid=${pid}}"
    else
        echo "helper_state: stopped"
    fi
}

require_root "$@"

NFT_ONLY=0
for arg in "$@"; do
    if [[ "$arg" == "--nft-only" ]]; then
        NFT_ONLY=1
    fi
done

stop_legacy_refresh_units
ensure_route_group

if [[ "$NFT_ONLY" -eq 1 ]]; then
    ensure_nftables_objects
    exit 0
fi

if command -v systemctl >/dev/null 2>&1 && [[ -f "/etc/systemd/system/${HELPER_UNIT}" ]]; then
    systemctl enable --now "$HELPER_UNIT"
else
    ensure_nftables_objects
    start_helper
fi

print_status
