#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--no-elevate" ]]; then
    shift
fi

exec "$SCRIPT_DIR/cursor_selective_routing_enable.sh" "$@"
