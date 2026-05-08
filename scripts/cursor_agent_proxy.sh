#!/bin/bash

set -e

find_agent_bin() {
    local candidate

    for candidate in \
        "${CURSOR_AGENT_BIN:-}" \
        "$HOME/.local/bin/agent" \
        "/usr/local/bin/agent" \
        "/usr/bin/agent"
    do
        if [[ -n "$candidate" && -x "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    command -v agent 2>/dev/null || true
}

is_local_only_command() {
    case "${1:-}" in
        -h|--help|-v|--version|help)
            return 0
            ;;
    esac

    return 1
}

agent_bin="$(find_agent_bin)"
proxychains_bin="${CURSOR_AGENT_PROXYCHAINS_BIN:-$(command -v proxychains4 2>/dev/null || true)}"
proxy_mode="${CURSOR_AGENT_PROXY_MODE:-always}"

if [[ -z "$agent_bin" ]]; then
    echo "agent binary was not found" >&2
    exit 1
fi

if is_local_only_command "${1:-}" || [[ "$proxy_mode" == "never" || -z "$proxychains_bin" ]]; then
    exec "$agent_bin" "$@"
fi

case "$proxy_mode" in
    always)
        exec "$proxychains_bin" -q "$agent_bin" "$@"
        ;;
    auto)
        if "$agent_bin" "$@"; then
            exit 0
        fi

        exec "$proxychains_bin" -q "$agent_bin" "$@"
        ;;
    never)
        exec "$agent_bin" "$@"
        ;;
    *)
        echo "unsupported CURSOR_AGENT_PROXY_MODE: $proxy_mode" >&2
        exit 1
        ;;
esac
