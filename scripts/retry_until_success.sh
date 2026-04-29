#!/usr/bin/env bash

set -u

usage() {
    cat <<'EOF'
Usage:
  retry_until_success.sh [--delay SECONDS] command [args...]

Examples:
  retry_until_success.sh sudo eopkg up -y
  retry_until_success.sh --delay 30 sudo /usr/local/bin/proxychains4 -q eopkg up -y
EOF
}

delay_seconds="${RETRY_DELAY_SECONDS:-15}"

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    usage
    exit 0
fi

if [ "${1:-}" = "--delay" ]; then
    if [ -z "${2:-}" ]; then
        echo "Missing value for --delay" >&2
        usage >&2
        exit 2
    fi

    delay_seconds="$2"
    shift 2
fi

if [ "$#" -eq 0 ]; then
    usage >&2
    exit 2
fi

attempt=1

while true; do
    echo "[retry] attempt ${attempt}: $*"

    if "$@"; then
        echo "[retry] command succeeded"
        exit 0
    fi

    exit_code=$?
    echo "[retry] command failed with exit code ${exit_code}; retrying in ${delay_seconds}s..." >&2
    sleep "${delay_seconds}"
    attempt=$((attempt + 1))
done
