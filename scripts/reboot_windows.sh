#!/usr/bin/env bash

set -euo pipefail

entry="${1:-auto-windows}"

if ! command -v bootctl >/dev/null 2>&1; then
    echo "bootctl not found" >&2
    exit 1
fi

if [[ "${EUID}" -ne 0 ]]; then
    exec sudo env "PATH=${PATH}" bash "$0" "$@"
fi

bootctl set-oneshot "${entry}"
echo "Next boot entry set to: ${entry}"
exec systemctl reboot
