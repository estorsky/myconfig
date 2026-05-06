#!/bin/bash

source ~/myconfig/scripts/common_envs.sh

LOCK_RING_COLOR="7893d8dd"
LOCK_RING_CLEAR_COLOR="7893d8dd"
LOCK_RING_CAPS_COLOR="7893d8dd"
LOCK_RING_VER_COLOR="7893d8dd"
LOCK_RING_WRONG_COLOR="d07d8edd"
LOCK_BS_HL_COLOR="91c4f0ff"
LOCK_CAPS_LOCK_BS_HL_COLOR="91c4f0ff"
LOCK_CAPS_LOCK_KEY_HL_COLOR="91c4f0ff"
LOCK_KEY_HL_COLOR="c1cae9ff"
LOCK_TEXT_COLOR="c1cae9ff"
LOCK_TEXT_CLEAR_COLOR="c1cae9ff"
LOCK_TEXT_CAPS_COLOR="c1cae9ff"
LOCK_TEXT_VER_COLOR="7aa2f7ff"
LOCK_TEXT_WRONG_COLOR="d07d8eff"
LOCK_LAYOUT_TEXT_COLOR="c1cae9ff"
LOCK_INSIDE_COLOR="1e2233aa"
LOCK_INSIDE_CLEAR_COLOR="1e2233aa"
LOCK_LAYOUT_BG_COLOR="1a1b2600"
LOCK_LAYOUT_BORDER_COLOR="1a1b2600"
LOCK_IMAGE_ARGS=()

set_multi_output_palette() {
    LOCK_RING_COLOR="7893d8dd"
    LOCK_RING_CLEAR_COLOR="7893d8dd"
    LOCK_RING_CAPS_COLOR="7893d8dd"
    LOCK_RING_VER_COLOR="7893d8dd"
    LOCK_RING_WRONG_COLOR="d07d8edd"
    LOCK_BS_HL_COLOR="91c4f0ff"
    LOCK_CAPS_LOCK_BS_HL_COLOR="91c4f0ff"
    LOCK_CAPS_LOCK_KEY_HL_COLOR="91c4f0ff"
    LOCK_KEY_HL_COLOR="c1cae9ff"
    LOCK_TEXT_COLOR="c1cae9ff"
    LOCK_TEXT_CLEAR_COLOR="c1cae9ff"
    LOCK_TEXT_CAPS_COLOR="c1cae9ff"
    LOCK_TEXT_VER_COLOR="7aa2f7ff"
    LOCK_TEXT_WRONG_COLOR="d07d8eff"
    LOCK_LAYOUT_TEXT_COLOR="c1cae9ff"
    LOCK_INSIDE_COLOR="1e223399"
}

set_lock_palette() {
    local image_path="$1"
    local brightness=""

    # In image mode the set of active outputs may change while the lockscreen
    # is already shown. Use a universal palette that remains visible on both
    # bright screenshots and black fallback outputs.
    set_multi_output_palette

    brightness="$(
        magick "$image_path" \
            -gravity center \
            -crop 240x240+0+0 +repage \
            -colorspace Gray \
            -format "%[fx:mean]" \
            info: 2>/dev/null || true
    )"

    if [[ -z "$brightness" ]]; then
        return 0
    fi

    if awk "BEGIN { exit !($brightness > 0.78) }"; then
        LOCK_INSIDE_COLOR="1e2233bb"
        LOCK_INSIDE_CLEAR_COLOR="$LOCK_INSIDE_COLOR"
    elif awk "BEGIN { exit !($brightness > 0.58) }"; then
        LOCK_INSIDE_COLOR="1e2233aa"
        LOCK_INSIDE_CLEAR_COLOR="$LOCK_INSIDE_COLOR"
    else
        LOCK_INSIDE_COLOR="1e223399"
        LOCK_INSIDE_CLEAR_COLOR="$LOCK_INSIDE_COLOR"
    fi
}

build_lock_images() {
    local runtime_dir lock_dir focused_output active_outputs output_name
    local raw_image blurred_image
    local -a output_list=()

    runtime_dir="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
    lock_dir="${runtime_dir}/swaylock"

    mkdir -p "$lock_dir" || return 1
    rm -f "${lock_dir}"/lock-*.png

    focused_output="$(
        swaymsg -t get_outputs -r 2>/dev/null | \
            jq -r '.[] | select(.active == true and .power == true and .focused == true) | .name' | \
            head -n 1
    )"

    active_outputs="$(
        swaymsg -t get_outputs -r 2>/dev/null | \
            jq -r '.[] | select(.active == true and .power == true) | .name'
    )"

    if [[ -z "$active_outputs" ]]; then
        return 1
    fi

    while IFS= read -r output_name; do
        [[ -n "$output_name" ]] || continue
        output_list+=("$output_name")
    done <<< "$active_outputs"

    if [[ -z "$focused_output" ]]; then
        focused_output="${output_list[0]}"
    fi

    LOCK_IMAGE_ARGS=()

    for output_name in "${output_list[@]}"; do
        raw_image="${lock_dir}/lock-${output_name}-raw.png"
        blurred_image="${lock_dir}/lock-${output_name}-blurred.png"

        grim -o "$output_name" "$raw_image" || continue

        if [[ "$output_name" == "$focused_output" ]]; then
            set_lock_palette "$raw_image"
        fi

        magick "$raw_image" \
            -colorspace sRGB \
            -filter Gaussian \
            -resize 50% \
            -blur 0x3 \
            -resize 200% \
            "$blurred_image" || {
                rm -f "$raw_image"
                continue
            }

        rm -f "$raw_image"
        LOCK_IMAGE_ARGS+=(--image "${output_name}:${blurred_image}")
    done

    [[ ${#LOCK_IMAGE_ARGS[@]} -gt 0 ]]
}

if ! pgrep -x swaylock &>/dev/null; then
    swaymsg input "${KEYBOARD}" xkb_switch_layout 0

    dunstctl close-all

    playerctl --all-players --no-messages pause

    build_lock_images || true

    if [[ ${#LOCK_IMAGE_ARGS[@]} -gt 0 ]]; then
        /usr/bin/swaylock \
            --daemonize \
            --color 000000 \
            "${LOCK_IMAGE_ARGS[@]}" \
            --scaling fill \
            --indicator-idle-visible \
            --show-keyboard-layout \
            --indicator-caps-lock \
            --indicator-radius 100 \
            --indicator-thickness 7 \
            --line-color 00000000 \
            --inside-color "$LOCK_INSIDE_COLOR" \
            --inside-clear-color "$LOCK_INSIDE_CLEAR_COLOR" \
            --separator-color 00000000 \
            --ring-color "$LOCK_RING_COLOR" \
            --ring-clear-color "$LOCK_RING_CLEAR_COLOR" \
            --ring-caps-lock-color "$LOCK_RING_CAPS_COLOR" \
            --ring-ver-color "$LOCK_RING_VER_COLOR" \
            --ring-wrong-color "$LOCK_RING_WRONG_COLOR" \
            --bs-hl-color "$LOCK_BS_HL_COLOR" \
            --caps-lock-bs-hl-color "$LOCK_CAPS_LOCK_BS_HL_COLOR" \
            --caps-lock-key-hl-color "$LOCK_CAPS_LOCK_KEY_HL_COLOR" \
            --key-hl-color "$LOCK_KEY_HL_COLOR" \
            --text-color "$LOCK_TEXT_COLOR" \
            --text-clear-color "$LOCK_TEXT_CLEAR_COLOR" \
            --text-caps-lock-color "$LOCK_TEXT_CAPS_COLOR" \
            --text-ver-color "$LOCK_TEXT_VER_COLOR" \
            --text-wrong-color "$LOCK_TEXT_WRONG_COLOR" \
            --layout-text-color "$LOCK_LAYOUT_TEXT_COLOR" \
            --layout-bg-color "$LOCK_LAYOUT_BG_COLOR" \
            --layout-border-color "$LOCK_LAYOUT_BORDER_COLOR"
    else
        /usr/bin/swaylock \
            --color 000000 \
            --daemonize \
            --indicator-idle-visible \
            --show-keyboard-layout \
            --indicator-caps-lock \
            --indicator-radius 100 \
            --indicator-thickness 7 \
            --line-color 00000000 \
            --inside-color "$LOCK_INSIDE_COLOR" \
            --inside-clear-color "$LOCK_INSIDE_CLEAR_COLOR" \
            --separator-color 00000000 \
            --ring-color "$LOCK_RING_COLOR" \
            --ring-clear-color "$LOCK_RING_CLEAR_COLOR" \
            --ring-caps-lock-color "$LOCK_RING_CAPS_COLOR" \
            --ring-ver-color "$LOCK_RING_VER_COLOR" \
            --ring-wrong-color "$LOCK_RING_WRONG_COLOR" \
            --bs-hl-color "$LOCK_BS_HL_COLOR" \
            --caps-lock-bs-hl-color "$LOCK_CAPS_LOCK_BS_HL_COLOR" \
            --caps-lock-key-hl-color "$LOCK_CAPS_LOCK_KEY_HL_COLOR" \
            --key-hl-color "$LOCK_KEY_HL_COLOR" \
            --text-color "$LOCK_TEXT_COLOR" \
            --text-clear-color "$LOCK_TEXT_CLEAR_COLOR" \
            --text-caps-lock-color "$LOCK_TEXT_CAPS_COLOR" \
            --text-ver-color "$LOCK_TEXT_VER_COLOR" \
            --text-wrong-color "$LOCK_TEXT_WRONG_COLOR" \
            --layout-text-color "$LOCK_LAYOUT_TEXT_COLOR" \
            --layout-bg-color "$LOCK_LAYOUT_BG_COLOR" \
            --layout-border-color "$LOCK_LAYOUT_BORDER_COLOR"
    fi
fi
