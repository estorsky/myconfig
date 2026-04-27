#!/bin/bash

set -euo pipefail

get_default_name() {
    local kind="$1"

    pactl info 2>/dev/null | awk -F': ' -v kind="$kind" '
        $1 == kind { print $2; exit }
    '
}

get_volume_percent() {
    local target="$1"
    local value

    value="$(
        pactl get-"$target"-volume "@DEFAULT_${target^^}@" 2>/dev/null | awk '
            NR == 1 {
                for (i = 1; i <= NF; i++) {
                    if ($i ~ /^[0-9]+%$/) {
                        gsub("%", "", $i)
                        print $i
                        exit
                    }
                }
            }
        '
    )"

    echo "${value:-0}"
}

get_mute_state() {
    local target="$1"

    pactl get-"$target"-mute "@DEFAULT_${target^^}@" 2>/dev/null | awk '
        { print $2; exit }
    '
}

pick_sink_icon() {
    local sink_name="$1"
    local volume="$2"

    if [[ "$sink_name" == bluez_output.* ]]; then
        echo ""
        return 0
    fi

    if (( volume == 0 )); then
        echo ""
    elif (( volume < 50 )); then
        echo ""
    else
        echo ""
    fi
}

main() {
    local sink_name
    local source_name
    local sink_volume
    local source_volume
    local sink_muted
    local source_muted
    local sink_icon
    local source_text=""
    local text
    local tooltip
    local css_class="normal"

    sink_name="$(get_default_name "Default Sink")"
    source_name="$(get_default_name "Default Source")"
    sink_volume="$(get_volume_percent sink)"
    sink_muted="$(get_mute_state sink)"
    sink_icon="$(pick_sink_icon "$sink_name" "$sink_volume")"

    if [[ -n "$source_name" && "$source_name" != *.monitor ]]; then
        source_volume="$(get_volume_percent source)"
        source_muted="$(get_mute_state source)"
        if [[ "$source_muted" == "yes" ]]; then
            source_text=" "
        else
            source_text=" ${source_volume}% "
        fi
    fi

    if [[ "$sink_muted" == "yes" ]]; then
        text="${source_text}"
        css_class="muted"
    else
        text="${sink_volume}% ${sink_icon}${source_text}"
        if [[ "$sink_name" == bluez_output.* ]]; then
            css_class="bluetooth"
        fi
    fi

    tooltip="sink: ${sink_name:-unknown}"
    if [[ -n "$source_name" ]]; then
        tooltip="${tooltip}\nsource: $source_name"
    fi

    TEXT="$text" TOOLTIP="$tooltip" CLASS_NAME="$css_class" python3 - <<'PY'
import json
import os

print(json.dumps({
    "text": os.environ["TEXT"],
    "tooltip": os.environ["TOOLTIP"],
    "class": os.environ["CLASS_NAME"],
}))
PY
}

main "$@"
