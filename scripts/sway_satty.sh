#!/bin/bash

set -euo pipefail

SATTY_BIN="${SATTY_BIN:-satty}"
SCREENSHOT_DIR="${SCREENSHOT_DIR:-$HOME/shared/screenshots}"
OUTPUT_PATTERN="${SCREENSHOT_DIR}/Screenshot-%Y-%m-%d_%H-%M-%S.png"

run_satty() {
    mkdir -p "$SCREENSHOT_DIR"

    "$SATTY_BIN" \
        --filename - \
        --floating-hack \
        --copy-command wl-copy \
        --initial-tool arrow \
        --actions-on-enter save-to-clipboard,save-to-file,exit \
        --actions-on-escape exit \
        --disable-notifications \
        --output-filename "$OUTPUT_PATTERN" \
        --app-id org.satty.satty
}

region() {
    local geometry

    geometry="$(slurp -d)" || return 0
    [[ -n "$geometry" ]] || return 0

    grim -g "$geometry" -t ppm - | run_satty
}

screen() {
    grim -t ppm - | run_satty
}

case "${1:-region}" in
    region) region ;;
    screen) screen ;;
    *)
        echo "$1 is not an option"
        exit 1
        ;;
esac
