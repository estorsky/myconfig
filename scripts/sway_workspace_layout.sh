#!/bin/bash

# Distribute sway workspaces across the active outputs, left to right.
#
# Port names (DP-9, DP-10, ...) are handed out dynamically by DP-MST hubs and
# swap between physically identical monitors, so they cannot be used as anchors.
# way-displays already arranges the outputs by serial (see ORDER in its cfg),
# therefore the on-screen geometry is the stable source of truth.
#
# Run it from way-displays CALLBACK_CMD so the layout is re-applied on every
# hotplug, and once at sway startup.

set -uo pipefail

WORKSPACE_COUNT=10
LOCK_FILE="/tmp/sway_workspace_layout.${UID}.lock"
LOG_FILE="/tmp/sway_workspace_layout.${UID}.log"

log() {
    printf '%s %s\n' "$(date '+%F %T')" "$*" >>"$LOG_FILE"
}

# way-displays reports its own log level rather than an outcome keyword: INFO
# once a rearrangement went through, WARNING or ERROR when it did not.
if [[ "${CALLBACK_LEVEL:-INFO}" != "INFO" ]]; then
    log "skipped, way-displays reported $CALLBACK_LEVEL"
    exit 0
fi

exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

command -v jq >/dev/null || { log "jq is missing"; exit 1; }

# The callback arrives while way-displays is still applying the new layout.
sleep 1

mapfile -t outputs < <(
    swaymsg -t get_outputs |
        jq -r '[.[] | select(.active)] | sort_by(.rect.x, .rect.y) | .[].name'
)

if ((${#outputs[@]} == 0)); then
    log "no active outputs"
    exit 0
fi

log "outputs left to right: ${outputs[*]}"

focused_ws=$(swaymsg -t get_workspaces | jq -r '.[] | select(.focused) | .name')

for ((i = 0; i < WORKSPACE_COUNT; i++)); do
    ws=$((i + 1))

    # Spread the workspaces evenly: two outputs give 1-5 / 6-10, three give
    # 1-4 / 5-7 / 8-10, a single output takes everything.
    target_index=$((i * ${#outputs[@]} / WORKSPACE_COUNT))
    target=${outputs[$target_index]}

    # The remaining outputs act as a fallback chain when the target disappears.
    fallback=("${outputs[@]:target_index+1}" "${outputs[@]:0:target_index}")

    swaymsg -q "workspace $ws output $target ${fallback[*]}"

    current=$(swaymsg -t get_workspaces | jq -r --arg ws "$ws" \
        '.[] | select(.name == $ws) | .output')

    [[ -z "$current" || "$current" == "$target" ]] && continue

    # Criteria move existing windows without stealing focus. Empty workspaces
    # match nothing, so those have to be visited explicitly.
    swaymsg -q "[workspace=\"^${ws}\$\"] move workspace to output $target"

    current=$(swaymsg -t get_workspaces | jq -r --arg ws "$ws" \
        '.[] | select(.name == $ws) | .output')

    if [[ -n "$current" && "$current" != "$target" ]]; then
        swaymsg -q "workspace --no-auto-back-and-forth $ws"
        swaymsg -q "move workspace to output $target"
    fi

    log "workspace $ws -> $target"
done

if [[ -n "$focused_ws" ]]; then
    swaymsg -q "workspace --no-auto-back-and-forth $focused_ws"
fi
