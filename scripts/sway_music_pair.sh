#!/bin/bash

set -u

SPOTIFY_KEY="spotify"
CASSETTE_KEY="cassette"
MUSIC_WORKSPACE="${MUSIC_WORKSPACE:-9}"
SPOTIFY_CMD=(spotify --enable-features=UseOzonePlatform --ozone-platform=wayland)
CASSETTE_CMD=(flatpak run space.rirusha.Cassette)

log() {
    printf '%s\n' "$*" >&2
}

window_exists() {
    local key="$1"

    swaymsg -t get_tree | jq -e --arg key "$key" '
        .. | objects
        | select(
            if $key == "spotify" then
                (.app_id? == "spotify")
                or (.window_properties.class? == "Spotify")
                or (.window_properties.instance? == "spotify")
            elif $key == "cassette" then
                (.app_id? == "space.rirusha.Cassette")
                or (.sandbox_app_id? == "space.rirusha.Cassette")
            else
                false
            end
        )
    ' >/dev/null
}

wait_for_window() {
    local key="$1"
    local attempts="${2:-60}"
    local delay="${3:-1}"
    local i

    for ((i = 0; i < attempts; i++)); do
        if window_exists "$key"; then
            return 0
        fi
        sleep "$delay"
    done

    return 1
}

focus_app() {
    local key="$1"

    if [[ "$key" == "$SPOTIFY_KEY" ]]; then
        swaymsg "[app_id=\"spotify\"] focus" >/dev/null 2>&1 \
            || swaymsg "[class=\"Spotify\"] focus" >/dev/null 2>&1 \
            || swaymsg "[instance=\"spotify\"] focus" >/dev/null 2>&1
        return
    fi

    swaymsg "[app_id=\"space.rirusha.Cassette\"] focus" >/dev/null 2>&1 \
        || swaymsg "[sandbox_app_id=\"space.rirusha.Cassette\"] focus" >/dev/null 2>&1
}

launch_if_missing() {
    local key="$1"
    shift

    if ! window_exists "$key"; then
        "$@" >/dev/null 2>&1 &
    fi
}

if [[ -z "${SWAYSOCK:-}" ]]; then
    log "SWAYSOCK is not set"
    exit 1
fi

current_workspace="$(
    swaymsg -t get_workspaces 2>/dev/null | jq -r '
        .[] | select(.focused) | .name
    ' | head -n 1
)"

swaymsg "workspace number ${MUSIC_WORKSPACE}" >/dev/null 2>&1 || true

launch_if_missing "$SPOTIFY_KEY" "${SPOTIFY_CMD[@]}"

if ! wait_for_window "$SPOTIFY_KEY" 90 1; then
    log "Spotify window did not appear"
    exit 1
fi

focus_app "$SPOTIFY_KEY"
swaymsg "split h" >/dev/null 2>&1 || true

launch_if_missing "$CASSETTE_KEY" "${CASSETTE_CMD[@]}"

if ! wait_for_window "$CASSETTE_KEY" 120 1; then
    log "Cassette window did not appear"
    exit 1
fi

if [[ -n "${current_workspace}" ]]; then
    swaymsg "workspace --no-auto-back-and-forth ${current_workspace}" >/dev/null || true
fi
