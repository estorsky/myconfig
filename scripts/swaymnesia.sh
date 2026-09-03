#!/bin/bash

# Start the swaymnesia daemon, which remembers where each window belongs and
# puts it back after a reboot. See https://github.com/estorsky/swaymnesia
#
# Must come up after way-displays has applied the output profile and after
# sway_workspace_layout.sh has spread the workspaces across the outputs:
# placing windows before the workspaces have found their monitors gets every
# position wrong.

set -uo pipefail

LOG_FILE="/tmp/swaymnesia.${UID}.log"
LOCK_FILE="${XDG_RUNTIME_DIR:-/tmp}/swaymnesia.lock"
BIN="${HOME}/.local/bin/swaymnesia"
WAIT_OUTPUTS=30

# Verbose logs every sway command the daemon issues, which is what makes a
# misplaced window diagnosable after the fact. Set to 0 once it has earned
# trust; the file is rotated on every start either way.
VERBOSE="${SWAYMNESIA_VERBOSE:-1}"

log() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"
}

# Keep exactly one previous run around, so a reload does not destroy the log of
# the startup that actually mattered.
if [[ -s "$LOG_FILE" ]]; then
    mv -f "$LOG_FILE" "${LOG_FILE}.prev"
fi

command -v "$BIN" >/dev/null || { log "$BIN is missing"; exit 1; }
command -v jq >/dev/null || { log "jq is missing"; exit 1; }

# exec_always re-runs on every sway reload, and the daemon's own lock would
# make the new instance refuse to start, so retire the old one first.
if [[ -r "$LOCK_FILE" ]]; then
    previous=$(<"$LOCK_FILE")
    if [[ -n "$previous" ]] && kill -0 "$previous" 2>/dev/null; then
        log "stopping previous daemon (pid $previous)"
        kill "$previous"
        # It saves its state on SIGTERM; do not race it for the lock.
        for _ in {1..10}; do
            kill -0 "$previous" 2>/dev/null || break
            sleep 0.5
        done
    fi
fi

for ((i = 0; i < WAIT_OUTPUTS; i++)); do
    active=$(swaymsg -t get_outputs | jq '[.[] | select(.active)] | length')
    ((active > 0)) && break
    sleep 1
done

if ((active == 0)); then
    log "no active outputs after ${WAIT_OUTPUTS}s, giving up"
    exit 1
fi

# sway_workspace_layout.sh sleeps a second before it starts moving workspaces.
sleep 4

args=(daemon)
[[ "$VERBOSE" == "1" ]] && args=(-v "${args[@]}")

log "starting daemon, $active active output(s), args: ${args[*]}"
swaymsg -t get_outputs |
    jq -r '.[] | select(.active) | "  output \(.name) \(.make) \(.model) serial=\(.serial) \(.rect.width)x\(.rect.height)"' \
    >>"$LOG_FILE" 2>&1

exec "$BIN" "${args[@]}" >>"$LOG_FILE" 2>&1
