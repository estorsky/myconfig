#!/bin/bash

set -euo pipefail

TABLE_NAME="${CURSOR_SELECTIVE_ROUTING_TABLE:-myconfig_cursor_route}"
STATE_DIR="${CURSOR_SELECTIVE_ROUTING_STATE_DIR:-/run/myconfig-cursor-routing}"
HELPER_UNIT="${CURSOR_SELECTIVE_ROUTING_HELPER_UNIT:-cursor-routing-helper.service}"
ROUTE_GROUP="${CURSOR_SELECTIVE_ROUTING_GROUP:-cursorroute}"
HELPER_PID_FILE="${STATE_DIR}/helper.pid"

helper_state() {
    if command -v systemctl >/dev/null 2>&1 && sudo systemctl is-active --quiet "$HELPER_UNIT"; then
        local main_pid
        main_pid="$(sudo systemctl show -p MainPID --value "$HELPER_UNIT" 2>/dev/null || true)"
        echo "running${main_pid:+ pid=${main_pid}}"
        return
    fi

    [[ -f "$HELPER_PID_FILE" ]] || {
        echo "stopped"
        return
    }

    local pid
    pid="$(<"$HELPER_PID_FILE")"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo "running pid=${pid}"
    else
        echo "stopped"
    fi
}

echo "helper_state: $(helper_state)"
echo "route_group: ${ROUTE_GROUP}"
echo "route_gid: $(getent group "$ROUTE_GROUP" | cut -d: -f3 | head -n 1)"

if sudo nft list table ip "$TABLE_NAME" >/dev/null 2>&1; then
    echo "nft_table: present"
    echo "output_chain:"
    sudo nft list chain ip "$TABLE_NAME" output 2>/dev/null || true
else
    echo "nft_table: missing"
fi
