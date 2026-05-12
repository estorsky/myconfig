#!/bin/bash

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_LINK="https://raw.githubusercontent.com/getsolus/3rd-party/master"
SOURCE_INSTALL_STATE_DIR="/usr/local/share/myconfig-source-installs"
SOURCE_REPO_CACHE_DIR="/var/tmp/myconfig-source-repos"

source "${INSTALL_DIR}/common_funcs.sh"

root_cmd() {
    if [[ $(id -u) -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

configure_chrome_wayland_desktop() {
    local desktop_file="$1"
    local browser_cmd="$2"
    local wayland_flag="--ozone-platform=wayland"
    local tmp_file

    [[ -f "${desktop_file}" ]] || return 0

    tmp_file="$(mktemp)"

    awk -v browser_cmd="${browser_cmd}" -v wayland_flag="${wayland_flag}" '
        BEGIN {
            entry_exec = "Exec=" browser_cmd " %U " wayland_flag
            window_exec = "Exec=" browser_cmd " " wayland_flag
            incognito_exec = "Exec=" browser_cmd " --incognito " wayland_flag
            section = ""
        }

        /^\[/ {
            section = $0
        }

        /^Exec=/ {
            if (section == "[Desktop Action new-private-window]") {
                print incognito_exec
                next
            }

            if (section == "[Desktop Action new-window]") {
                print window_exec
                next
            }

            if (section == "[Desktop Entry]") {
                print entry_exec
                next
            }
        }

        {
            print
        }
    ' "${desktop_file}" > "${tmp_file}"

    root_cmd install -m 644 "${tmp_file}" "${desktop_file}"
    rm -f "${tmp_file}"
}

source_install_state_path() {
    echo "${SOURCE_INSTALL_STATE_DIR}/$1.id"
}

read_source_install_state() {
    local state_path
    state_path="$(source_install_state_path "$1")"

    if root_cmd test -f "$state_path"; then
        root_cmd cat "$state_path"
    fi
}

write_source_install_state() {
    local state_path
    state_path="$(source_install_state_path "$1")"

    root_cmd mkdir -p "$SOURCE_INSTALL_STATE_DIR"
    printf '%s\n' "$2" | root_cmd tee "$state_path" >/dev/null
}

installed_binary_path() {
    local candidate

    for candidate in \
        "/usr/local/bin/$1" \
        "/usr/bin/$1" \
        "/bin/$1" \
        "/usr/local/sbin/$1" \
        "/usr/sbin/$1" \
        "/sbin/$1"
    do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    command -v "$1" 2>/dev/null || true
}

proxychains4_binary_path() {
    installed_binary_path "proxychains4"
}

run_with_proxychains_fallback() {
    local proxy_bin exit_code

    "$@"
    exit_code=$?

    if [[ "$exit_code" -eq 0 ]]; then
        return 0
    fi

    proxy_bin="$(proxychains4_binary_path)"

    if [[ -z "$proxy_bin" ]]; then
        return "$exit_code"
    fi

    "$proxy_bin" -q "$@"
}

cursor_agent_binary_path() {
    local candidate

    for candidate in \
        "$HOME/.local/bin/agent" \
        "/usr/local/bin/agent" \
        "/usr/bin/agent"
    do
        if [[ -x "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done

    command -v agent 2>/dev/null || true
}

cursor_agent_is_local_only_command() {
    case "${1:-}" in
        -h|--help|-v|--version|help)
            return 0
            ;;
    esac

    return 1
}

run_cursor_agent_command() {
    local agent_bin proxy_bin
    agent_bin="$(cursor_agent_binary_path)"

    if [[ -z "$agent_bin" ]]; then
        echo "agent binary is not installed"
        return 1
    fi

    if cursor_agent_is_local_only_command "${1:-}"; then
        "$agent_bin" "$@"
        return $?
    fi

    if "$agent_bin" "$@"; then
        return 0
    fi

    proxy_bin="$(proxychains4_binary_path)"
    [[ -n "$proxy_bin" ]] || return 1

    "$proxy_bin" -q "$agent_bin" "$@"
}

proxychains4_library_path() {
    local candidate

    for candidate in \
        "/usr/local/lib/libproxychains4.so" \
        "/usr/local/lib64/libproxychains4.so" \
        "/usr/lib/libproxychains4.so" \
        "/usr/lib64/libproxychains4.so"
    do
        if [[ -f "$candidate" ]]; then
            echo "$candidate"
            return 0
        fi
    done
}

source_repo_cache_path() {
    echo "${SOURCE_REPO_CACHE_DIR}/$1"
}

sync_source_repo() {
    local package_name="$1"
    local repo_url="$2"
    local repo_path default_branch

    repo_path="$(source_repo_cache_path "$package_name")"
    root_cmd mkdir -p "$SOURCE_REPO_CACHE_DIR"

    if ! root_cmd test -d "$repo_path/.git"; then
        root_cmd rm -rf "$repo_path"
        root_cmd git clone --recurse-submodules "$repo_url" "$repo_path" >&2
    else
        root_cmd git -C "$repo_path" remote set-url origin "$repo_url"
        root_cmd git -C "$repo_path" fetch --tags origin >&2
        default_branch="$(root_cmd git -C "$repo_path" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null || true)"

        if [[ -z "$default_branch" ]]; then
            default_branch="$(root_cmd git -C "$repo_path" remote show origin 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -n 1)"
            [[ -n "$default_branch" ]] && default_branch="origin/$default_branch"
        fi

        if [[ -n "$default_branch" ]]; then
            default_branch="${default_branch#origin/}"
            root_cmd git -C "$repo_path" checkout "$default_branch" >&2
            root_cmd git -C "$repo_path" pull --ff-only --tags origin "$default_branch" >&2
        else
            root_cmd git -C "$repo_path" pull --ff-only --tags >&2
        fi

        if root_cmd test -f "$repo_path/.gitmodules"; then
            root_cmd git -C "$repo_path" submodule update --init --recursive >&2
        fi
    fi

    printf '%s\n' "$repo_path"
}

prepare_source_build_dir() {
    local package_name="$1"
    local repo_path="$2"
    local build_path="/tmp/$package_name"

    root_cmd rm -rf "$build_path"
    root_cmd git clone --recurse-submodules "$repo_path" "$build_path" >/dev/null || return 1
    printf '%s\n' "$build_path"
}

should_skip_source_install() {
    local package_name="$1"
    local target_id="$2"
    local target_version="$3"
    local installed_version="$4"
    local installed_label="${target_version:-$target_id}"
    local recorded_id

    recorded_id="$(read_source_install_state "$package_name")"

    if [[ -n "$recorded_id" && "$recorded_id" == "$target_id" ]]; then
        echo "$package_name is already up to date ($installed_label)"
        return 0
    fi

    if [[ -z "$recorded_id" && -n "$target_version" && -n "$installed_version" && "$installed_version" == "$target_version" ]]; then
        echo "$package_name is already installed at $installed_label"
        write_source_install_state "$package_name" "$target_id"
        return 0
    fi

    return 1
}

latest_tag_version() {
    git describe --tags --abbrev=0 2>/dev/null | sed 's/^[^0-9]*//'
}

meson_project_version() {
    sed -En "s/.*version[[:space:]]*:[[:space:]]*'([^']+)'.*/\1/p" meson.build | head -n 1
}

makefile_version() {
    local makefile_path version

    for makefile_path in Makefile makefile GNUmakefile config.mk
    do
        if [[ -f "$makefile_path" ]]; then
            version="$(
                awk '
                /^[[:space:]]*VERSION[[:space:]]*\??=/ {
                    value = $0
                    sub(/^[[:space:]]*VERSION[[:space:]]*\??=[[:space:]]*/, "", value)
                    gsub(/^"/, "", value)
                    gsub(/"$/, "", value)
                    print value
                    exit
                }
            ' "$makefile_path"
            )"

            if [[ -n "$version" ]]; then
                printf '%s\n' "$version"
                return 0
            fi
        fi
    done
}

cargo_manifest_version() {
    sed -En 's/^version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/p' Cargo.toml | head -n 1
}

source_version__wl_clipboard() {
    local version
    version="$(latest_tag_version)"
    [[ -n "$version" ]] || version="$(meson_project_version)"
    echo "$version"
}

installed_version__wl_clipboard() {
    local bin_path
    bin_path="$(installed_binary_path "wl-copy")"
    [[ -n "$bin_path" ]] || return 0
    "$bin_path" --version 2>/dev/null | awk 'NR == 1 { print $2 }'
}

source_version__rofi_wayland() {
    git rev-parse --short=8 HEAD
}

installed_version__rofi_wayland() {
    local bin_path
    bin_path="$(installed_binary_path "rofi")"
    [[ -n "$bin_path" ]] || return 0
    "$bin_path" -version 2>/dev/null | sed -n 's/^Version: \([^ ]*\).*/\1/p'
}

source_version__rofi_calc() {
    local version
    version="$(latest_tag_version)"
    [[ -n "$version" ]] || version="$(meson_project_version)"
    echo "$version"
}

source_id__rofi_calc() {
    local commit patch_hash patch_path
    patch_path="${INSTALL_DIR}/../patches/rofi-calc/combi.patch"
    commit="$(git rev-parse HEAD)"

    if [[ -f "$patch_path" ]]; then
        patch_hash="$(sha256sum "$patch_path" | awk '{ print $1 }')"
        echo "${commit}:${patch_hash}"
    else
        echo "$commit"
    fi
}

source_version__swaylock_effects() {
    local version
    version="$(latest_tag_version)"
    [[ -n "$version" ]] || version="$(meson_project_version)"
    echo "$version"
}

installed_version__swaylock_effects() {
    local bin_path
    bin_path="$(installed_binary_path "swaylock")"
    [[ -n "$bin_path" ]] || return 0
    "$bin_path" --version 2>/dev/null | awk 'NR == 1 { print $3 }' | sed 's/^v//; s/-.*$//'
}

source_version__way_displays() {
    local version
    version="$(makefile_version)"
    [[ -n "$version" ]] || version="$(latest_tag_version)"
    echo "$version"
}

installed_version__way_displays() {
    local bin_path
    bin_path="$(installed_binary_path "way-displays")"
    [[ -n "$bin_path" ]] || return 0
    "$bin_path" --version 2>/dev/null | awk 'NR == 1 { print $3 }'
}

source_version__satty() {
    local version
    version="$(latest_tag_version)"
    [[ -n "$version" ]] || version="$(cargo_manifest_version)"
    echo "$version"
}

installed_version__satty() {
    local bin_path
    bin_path="$(installed_binary_path "satty")"
    [[ -n "$bin_path" ]] || return 0
    "$bin_path" --version 2>/dev/null | awk 'NR == 1 { print $2 }'
}

source_version__asusctl() {
    local version
    version="$(latest_tag_version)"
    [[ -n "$version" ]] || version="$(cargo_manifest_version)"
    echo "$version"
}

installed_version__asusctl() {
    local bin_path
    bin_path="$(installed_binary_path "asusctl")"
    [[ -n "$bin_path" ]] || return 0
    "$bin_path" info 2>/dev/null | sed -n 's/^Software version: //p' | awk 'NR == 1 { print $1 }'
}

source_version__supergfxctl() {
    local version
    version="$(latest_tag_version)"
    [[ -n "$version" ]] || version="$(cargo_manifest_version)"
    echo "$version"
}

installed_version__supergfxctl() {
    local bin_path
    bin_path="$(installed_binary_path "supergfxctl")"
    [[ -n "$bin_path" ]] || return 0
    "$bin_path" --version 2>/dev/null | awk 'NR == 1 { print $1 }'
}

source_version__proxychains4() {
    local version

    version="$(git describe --tags --match 'v[0-9]*' 2>/dev/null | sed -e 's/^v//' -e 's/-/-git-/')"
    [[ -n "$version" ]] || version="$(tr -d '\n' < VERSION 2>/dev/null)"
    echo "$version"
}

installed_version__proxychains4() {
    local lib_path

    lib_path="$(proxychains4_library_path)"
    [[ -n "$lib_path" ]] || return 0

    strings "$lib_path" 2>/dev/null | sed -n 's/^\([0-9][0-9.]*\(-git-[0-9][0-9]*-g[0-9a-f]\+\)\?\)$/\1/p' | head -n 1
}

install__cursor_agent () {
    set -x

    local agent_bin proxy_bin install_cmd
    agent_bin="$(cursor_agent_binary_path)"

    if [[ -n "$agent_bin" ]]; then
        run_cursor_agent_command update
        return $?
    fi

    proxy_bin="$(proxychains4_binary_path)"
    install_cmd='set -o pipefail; curl https://cursor.com/install -fsS | bash'

    if bash -lc "$install_cmd"; then
        return 0
    fi

    [[ -n "$proxy_bin" ]] || return 1
    "$proxy_bin" -q bash -lc "$install_cmd"
}

hiddify_target_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != "root" ]]; then
        printf '%s\n' "${SUDO_USER}"
        return 0
    fi

    id -un
}

hiddify_target_home() {
    local target_user="$1"

    getent passwd "$target_user" | cut -d: -f6 | head -n 1
}

telegram_download_proxy() {
    local candidate

    for candidate in \
        "${TELEGRAM_DOWNLOAD_PROXY:-}" \
        "${ALL_PROXY:-}" \
        "${all_proxy:-}" \
        "${HTTPS_PROXY:-}" \
        "${https_proxy:-}" \
        "${HTTP_PROXY:-}" \
        "${http_proxy:-}"
    do
        if [[ -n "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done

    printf '%s\n' "socks5h://127.0.0.1:12334"
}

telegram_version_from_download_url() {
    sed -En 's#^.*/tsetup\.([^/]+)\.tar\.xz$#\1#p' <<<"$1"
}

telegram_state_path() {
    local target_home="$1"

    printf '%s\n' "${target_home}/.local/state/myconfig/telegram.id"
}

read_telegram_install_state() {
    local target_home="$1"
    local state_path

    state_path="$(telegram_state_path "$target_home")"
    [[ -f "$state_path" ]] || return 0
    < "$state_path" tr -d '\n'
}

write_telegram_install_state() {
    local target_home="$1"
    local state_path

    state_path="$(telegram_state_path "$target_home")"
    mkdir -p "$(dirname "$state_path")" || return 1
    printf '%s\n' "$2" > "$state_path"
}

installed_version__hiddify() {
    local target_home="$1"
    local version_path="${target_home}/Dropbox/bin/hiddify/data/flutter_assets/version.json"

    [[ -f "$version_path" ]] || return 0
    jq -r '.version // empty' "$version_path"
}

install__nm_tray () {
    set -x

    cd /tmp/

    rm -rf /tmp/nm-tray
    gclonecd https://github.com/palinek/nm-tray.git
    mkdir build
    cd build
    cmake ..
    sudo make install

    # sway
    # exec sleep 5 && QT_QPA_PLATFORMTHEME=gtk3 nm-tray
    # for_window [app_id="nm-tray"] {
        # floating enable
        # move position mouse
        # border none
    # }
}

install__wl_clipboard () {
    set -x

    local repo_path build_path source_id source_version installed_version

    repo_path="$(sync_source_repo "wl-clipboard" "https://github.com/bugaevc/wl-clipboard.git")" || return 1
    cd "$repo_path" || return 1
    source_id="$(git rev-parse HEAD)"
    source_version="$(source_version__wl_clipboard)"
    installed_version="$(installed_version__wl_clipboard)"

    if should_skip_source_install "wl-clipboard" "$source_id" "$source_version" "$installed_version"; then
        return 0
    fi

    build_path="$(prepare_source_build_dir "wl-clipboard" "$repo_path")" || return 1
    cd "$build_path" || return 1
    meson build || return 1
    cd build || return 1
    sudo ninja install || return 1
    write_source_install_state "wl-clipboard" "$source_id"
}

install__rofi_wayland () {
    set -x

    local repo_path build_path source_id source_version installed_version

    repo_path="$(sync_source_repo "rofi-wayland" "https://github.com/in0ni/rofi-wayland.git")" || return 1
    cd "$repo_path" || return 1
    source_id="$(git rev-parse HEAD)"
    source_version="$(source_version__rofi_wayland)"
    installed_version="$(installed_version__rofi_wayland)"

    if should_skip_source_install "rofi-wayland" "$source_id" "$source_version" "$installed_version"; then
        return 0
    fi

    build_path="$(prepare_source_build_dir "rofi-wayland" "$repo_path")" || return 1
    cd "$build_path" || return 1
    meson setup build || return 1
    ninja -C build || return 1
    sudo ninja -C build install || return 1
    write_source_install_state "rofi-wayland" "$source_id"
}

install__rofi_calc () {
    set -x

    local repo_path build_path source_id source_version

    repo_path="$(sync_source_repo "rofi-calc" "https://github.com/svenstaro/rofi-calc.git")" || return 1
    cd "$repo_path" || return 1
    source_id="$(source_id__rofi_calc)"
    source_version="$(source_version__rofi_calc)"

    if should_skip_source_install "rofi-calc" "$source_id" "$source_version" ""; then
        return 0
    fi

    build_path="$(prepare_source_build_dir "rofi-calc" "$repo_path")" || return 1
    cd "$build_path" || return 1

    if [ -f "${INSTALL_DIR}/../patches/rofi-calc/combi.patch" ]; then
        git apply "${INSTALL_DIR}/../patches/rofi-calc/combi.patch" || return 1
    fi

    export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH
    meson setup build || return 1
    meson compile -C build/ || return 1
    cd build || return 1
    sudo meson install || return 1
    write_source_install_state "rofi-calc" "$source_id"
}

install__swaylock_effects () {
    set -x

    local repo_path build_path source_id source_version installed_version

    repo_path="$(sync_source_repo "swaylock-effects" "https://github.com/jirutka/swaylock-effects.git")" || return 1
    cd "$repo_path" || return 1
    source_id="$(git rev-parse HEAD)"
    source_version="$(source_version__swaylock_effects)"
    installed_version="$(installed_version__swaylock_effects)"

    if should_skip_source_install "swaylock-effects" "$source_id" "$source_version" "$installed_version"; then
        return 0
    fi

    build_path="$(prepare_source_build_dir "swaylock-effects" "$repo_path")" || return 1
    cd "$build_path" || return 1
    meson build || return 1
    ninja -C build || return 1
    sudo ninja -C build install || return 1
    write_source_install_state "swaylock-effects" "$source_id"
}

# sudo usermod -a -G input "${USER}"
install__way_displays () {
    set -x

    local repo_path build_path source_id source_version installed_version

    repo_path="$(sync_source_repo "way-displays" "https://github.com/alex-courtis/way-displays.git")" || return 1
    cd "$repo_path" || return 1
    source_id="$(git rev-parse HEAD)"
    source_version="$(source_version__way_displays)"
    installed_version="$(installed_version__way_displays)"

    if should_skip_source_install "way-displays" "$source_id" "$source_version" "$installed_version"; then
        return 0
    fi

    build_path="$(prepare_source_build_dir "way-displays" "$repo_path")" || return 1
    cd "$build_path" || return 1
    sudo make install || return 1
    write_source_install_state "way-displays" "$source_id"
}

# sudo eopkg it slurp libgtk-4-devel libadwaita-devel libepoxy-devel
install__satty () {
    set -x

    local repo_path build_path source_id source_version installed_version

    repo_path="$(sync_source_repo "satty" "https://github.com/Satty-org/Satty.git")" || return 1
    cd "$repo_path" || return 1
    source_id="$(git rev-parse HEAD)"
    source_version="$(source_version__satty)"
    installed_version="$(installed_version__satty)"

    if should_skip_source_install "satty" "$source_id" "$source_version" "$installed_version"; then
        return 0
    fi

    build_path="$(prepare_source_build_dir "satty" "$repo_path")" || return 1
    cd "$build_path" || return 1
    make build-release || return 1
    sudo PREFIX=/usr/local make install || return 1
    write_source_install_state "satty" "$source_id"
}

install__earlyoom () {
    set -x

    cd /tmp/

    rm -rf /tmp/earlyoom
    gclonecd https://github.com/rfjakob/earlyoom.git
    make
    sudo make install
    sudo systemctl start earlyoom

    # sudo vim /etc/default/earlyoom
    # EARLYOOM_ARGS="-m 2 -s 100,100 -r 0" # -n
    # sudo journalctl -u earlyoom | grep sending
}

# sudo eopkg it pango-devel libjpeg-turbo-devel hyprutils-devel hyprwayland-scanner
install__hyprpicker () {
    set -x

    cd /tmp/

    rm -rf /tmp/hyprpicker
    gclonecd https://github.com/hyprwm/hyprpicker.git

    cmake --no-warn-unused-cli -DCMAKE_BUILD_TYPE:STRING=Release -DCMAKE_INSTALL_PREFIX:PATH=/usr -S . -B ./build
    cmake --build ./build --config Release --target hyprpicker -j`nproc 2>/dev/null || getconf _NPROCESSORS_CONF`
    sudo cmake --install ./build
}

install__xkb_switch () {
    set -x

    ldconfig /usr/local/lib

    cd /tmp/

    if [[ "$1" == "i3" ]]; then
        # jsoncpp-devel libsigc++-devel i3-devel
        rm -rf /tmp/xkb-switch-i3
        gclonecd https://github.com/zebradil/xkb-switch-i3
        git submodule update --init
    else
        rm -rf /tmp/xkb-switch
        gclonecd https://github.com/grwlf/xkb-switch.git
    fi

    mkdir build && cd build
    cmake -DCMAKE_INSTALL_PREFIX:PATH=/usr ..
    make

    make install

    cd /tmp/
}

install__google_chrome () {
    # Use secure DNS (Add custom DNS service provider): https://dns.comss.one/dns-query
    #
    # Or --proxy-server="socks5://127.0.0.1:12334"
    # https://github.com/hiddify/hiddify-app
    # ./Hiddify-Linux-x64.AppImage --appimage-extract

    sudo eopkg bi -q --ignore-safety ${INSTALL_LINK}/network/web/browser/google-chrome-stable/pspec.xml
    sudo eopkg bi -q --ignore-safety ${INSTALL_LINK}/network/web/browser/google-chrome-beta/pspec.xml
    sudo eopkg it -y google-chrome-*.eopkg; sudo rm google-chrome-*.eopkg

    configure_chrome_wayland_desktop /usr/share/applications/google-chrome.desktop /usr/bin/google-chrome-stable
    configure_chrome_wayland_desktop /usr/share/applications/google-chrome-beta.desktop /usr/bin/google-chrome-beta

    # for Wayland
    # Go to chrome://flags
    # Search "Preferred Ozone platform"
    # Set it to "Wayland"
    # And 'Use system title bar and borders' - on
    # Vulkan -> enable
}

install__spotify () {
    sudo eopkg bi -q --ignore-safety ${INSTALL_LINK}/multimedia/music/spotify/pspec.xml
    sudo eopkg it -y spotify*.eopkg; sudo rm spotify*.eopkg
}

install__sublime_text_3 () {
    sudo eopkg bi -q --ignore-safety ${INSTALL_LINK}/programming/sublime-text-3/pspec.xml
    sudo eopkg it -y sublime*.eopkg; sudo rm sublime*.eopkg
}

install__team_viewer () {
    sudo eopkg bi -q --ignore-safety ${INSTALL_LINK}/network/util/teamviewer/pspec.xml
    sudo eopkg it -y teamviewer*.eopkg; sudo rm teamviewer*.eopkg
    sudo systemctl start teamviewerd.service
}

install__ms_fonts () {
    sudo eopkg bi -q --ignore-safety ${INSTALL_LINK}/desktop/font/mscorefonts/pspec.xml
    sudo eopkg it -y mscorefonts*.eopkg; sudo rm mscorefonts*.eopkg
}

install__anydesk () {
    sudo eopkg bi -q --ignore-safety ${INSTALL_LINK}/network/util/anydesk/pspec.xml
    sudo eopkg it -y anydesk*.eopkg; sudo rm anydesk*.eopkg
}

is_asus_zephyrus_g14 () {
    if [ -f /sys/class/dmi/id/product_name ]; then
        local product_name=$(cat /sys/class/dmi/id/product_name)
        if [[ "$product_name" == *"Zephyrus G14"* ]]; then
            return 0
        fi
    fi
    return 1
}

install__myasus_hook () {
    local hook_source hook_target
    MYASUS_HOOK_CHANGED=0

    hook_source="${INSTALL_DIR}/myasus_asusd_hook.sh"
    hook_target="/usr/local/bin/myasus-hook"

    if root_cmd test -f "$hook_target" && root_cmd cmp -s "$hook_source" "$hook_target" && root_cmd test -x "$hook_target"; then
        return 0
    fi

    root_cmd install -Dm755 "$hook_source" "$hook_target" || return 1
    MYASUS_HOOK_CHANGED=1
}

configure__asusd_power_hooks () {
    local config_source config_path tmp_config
    ASUSD_POWER_HOOKS_CHANGED=0

    config_source="${INSTALL_DIR}/../dotfiles/asus/asusd.ron.example"
    config_path="/etc/asusd/asusd.ron"
    tmp_config="$(mktemp)" || return 1

    if root_cmd test -f "$config_path"; then
        root_cmd cat "$config_path" > "$tmp_config" || {
            rm -f "$tmp_config"
            return 1
        }
    else
        cp "$config_source" "$tmp_config" || {
            rm -f "$tmp_config"
            return 1
        }
    fi

    if ! python3 - "$tmp_config" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()

patterns = {
    r'(?m)^(\s*ac_command:\s*).*$': r'\1"/usr/local/bin/myasus-hook ac",',
    r'(?m)^(\s*bat_command:\s*).*$': r'\1"/usr/local/bin/myasus-hook battery",',
}

for pattern, replacement in patterns.items():
    text, count = re.subn(pattern, replacement, text)
    if count == 0:
        raise SystemExit(f"failed to patch {path}: pattern not found: {pattern}")

path.write_text(text)
PY
    then
        rm -f "$tmp_config"
        return 1
    fi

    if ! root_cmd test -f "$config_path" || ! root_cmd cmp -s "$tmp_config" "$config_path"; then
        root_cmd install -Dm644 "$tmp_config" "$config_path" || {
            rm -f "$tmp_config"
            return 1
        }
        ASUSD_POWER_HOOKS_CHANGED=1
    fi

    rm -f "$tmp_config"
}

configure__asusd_fan_curves () {
    local fan_curves_source fan_curves_path
    ASUSD_FAN_CURVES_CHANGED=0

    fan_curves_source="${INSTALL_DIR}/../dotfiles/asus/fan_curves.ron.example"
    fan_curves_path="/etc/asusd/fan_curves.ron"

    if ! root_cmd test -f "$fan_curves_path"; then
        root_cmd install -Dm644 "$fan_curves_source" "$fan_curves_path" || return 1
        ASUSD_FAN_CURVES_CHANGED=1
    fi
}

# sudo eopkg it clang-devel fontconfig-devel cmake libxkbcommon-devel rust seatd-devel libinput-devel
install__asusctl () {
    set -x

    local repo_path build_path source_id source_version installed_version
    local asusctl_changed=0

    if ! is_asus_zephyrus_g14; then
        return 0
    fi

    repo_path="$(sync_source_repo "asusctl" "https://gitlab.com/asus-linux/asusctl.git")" || return 1
    cd "$repo_path" || return 1
    source_id="$(git rev-parse HEAD)"
    source_version="$(source_version__asusctl)"
    installed_version="$(installed_version__asusctl)"

    if ! should_skip_source_install "asusctl" "$source_id" "$source_version" "$installed_version"; then
        build_path="$(prepare_source_build_dir "asusctl" "$repo_path")" || return 1
        cd "$build_path" || return 1
        make || return 1
        sudo make install || return 1
        write_source_install_state "asusctl" "$source_id"
        asusctl_changed=1
    fi

    install__myasus_hook || return 1
    configure__asusd_power_hooks || return 1
    configure__asusd_fan_curves || return 1

    if (( asusctl_changed || MYASUS_HOOK_CHANGED || ASUSD_POWER_HOOKS_CHANGED || ASUSD_FAN_CURVES_CHANGED )); then
        sudo systemctl daemon-reload || return 1
        sudo systemctl restart asusd || return 1
    fi
}

install__supergfxctl () {
    set -x

    local repo_path build_path source_id source_version installed_version

    if ! is_asus_zephyrus_g14; then
        return 0
    fi

    repo_path="$(sync_source_repo "supergfxctl" "https://gitlab.com/asus-linux/supergfxctl.git")" || return 1
    cd "$repo_path" || return 1
    source_id="$(git rev-parse HEAD)"
    source_version="$(source_version__supergfxctl)"
    installed_version="$(installed_version__supergfxctl)"

    if should_skip_source_install "supergfxctl" "$source_id" "$source_version" "$installed_version"; then
        return 0
    fi

    build_path="$(prepare_source_build_dir "supergfxctl" "$repo_path")" || return 1
    cd "$build_path" || return 1
    make || return 1
    sudo make install || return 1

    sudo systemctl enable supergfxd.service --now || return 1
    sudo systemctl daemon-reload || return 1
    sudo systemctl restart asusd || return 1
    write_source_install_state "supergfxctl" "$source_id"
}

install__proxychains4 () {
    set -x

    local repo_path build_path source_id source_version installed_version

    repo_path="$(sync_source_repo "proxychains-ng" "https://github.com/rofl0r/proxychains-ng.git")" || return 1
    cd "$repo_path" || return 1
    source_id="$(git rev-parse HEAD)"
    source_version="$(source_version__proxychains4)"
    installed_version="$(installed_version__proxychains4)"

    if should_skip_source_install "proxychains4" "$source_id" "$source_version" "$installed_version"; then
        return 0
    fi

    build_path="$(prepare_source_build_dir "proxychains-ng" "$repo_path")" || return 1
    cd "$build_path" || return 1
    ./configure || return 1
    make || return 1
    sudo make install || return 1

    if ! sudo test -f /usr/local/etc/proxychains.conf; then
        sudo make install-config || return 1
    fi

    write_source_install_state "proxychains4" "$source_id"
}

install__telegram () {
    set -x

    local target_user target_group target_home install_root app_dir link_path
    local download_url resolved_url source_id source_version installed_version recorded_id
    local tmp_dir archive_path extracted_dir backup_dir download_proxy
    local -a resolve_args download_args

    target_user="$(hiddify_target_user)"
    target_group="$(id -gn "$target_user")"
    target_home="$(hiddify_target_home "$target_user")"

    if [[ -z "$target_home" || ! -d "$target_home" ]]; then
        echo "failed to detect home directory for telegram target user: $target_user"
        return 1
    fi

    install_root="${target_home}/Dropbox/bin"
    app_dir="${install_root}/telegram-desktop"
    link_path="${install_root}/telegram"
    download_url="https://telegram.org/dl/desktop/linux"
    installed_version=""
    download_proxy="$(telegram_download_proxy)"
    resolve_args=(-fsSL --retry 5 --retry-all-errors --retry-delay 2)
    download_args=(-fL --progress-bar --retry 5 --retry-all-errors --retry-delay 2)
    backup_dir=""

    if [[ -n "$download_proxy" ]]; then
        resolve_args+=(--proxy "$download_proxy")
        download_args+=(--proxy "$download_proxy")
    fi

    resolved_url="$(curl "${resolve_args[@]}" -o /dev/null -w '%{url_effective}' "$download_url")" || return 1
    source_id="$resolved_url"
    source_version="$(telegram_version_from_download_url "$resolved_url")"
    recorded_id="$(read_telegram_install_state "$target_home")"

    if [[ -n "$recorded_id" && "$recorded_id" == "$source_id" ]]; then
        echo "telegram is already up to date (${source_version:-$source_id})"
        return 0
    fi

    tmp_dir="$(mktemp -d)"
    archive_path="${tmp_dir}/telegram.tar.xz"

    trap 'rm -rf "$tmp_dir"; trap - RETURN' RETURN

    mkdir -p "$install_root" || return 1
    curl "${download_args[@]}" "$download_url" -o "$archive_path" || return 1
    tar -xf "$archive_path" -C "$tmp_dir" || return 1

    extracted_dir="${tmp_dir}/Telegram"

    [[ -x "${extracted_dir}/Telegram" ]] || {
        echo "telegram archive did not contain Telegram binary"
        return 1
    }

    [[ -x "${extracted_dir}/Updater" ]] || {
        echo "telegram archive did not contain Updater binary"
        return 1
    }

    if [[ -d "${install_root}/Telegram" && ! -e "$app_dir" ]]; then
        mv "${install_root}/Telegram" "$app_dir" || return 1
    fi

    if [[ -e "$app_dir" ]]; then
        backup_dir="${tmp_dir}/previous-telegram"
        mv "$app_dir" "$backup_dir" || return 1
    fi

    if ! mv "$extracted_dir" "$app_dir"; then
        if [[ -n "$backup_dir" && -e "$backup_dir" ]]; then
            mv "$backup_dir" "$app_dir" || true
        fi
        return 1
    fi

    ln -sfn "${app_dir}/Telegram" "$link_path" || return 1
    chown -R "${target_user}:${target_group}" "$app_dir" || return 1
    chown -h "${target_user}:${target_group}" "$link_path" || return 1
    write_telegram_install_state "$target_home" "$source_id" || return 1
}

install__hiddify () {
    set -x

    local target_user target_group target_home install_root wrapper_path
    local app_dir installed_version latest_version asset_url asset_digest
    local release_json tmp_dir appimage_path extracted_dir backup_dir

    if ! command -v jq >/dev/null 2>&1; then
        echo "jq is required to update hiddify"
        return 1
    fi

    target_user="$(hiddify_target_user)"
    target_group="$(id -gn "$target_user")"
    target_home="$(hiddify_target_home "$target_user")"

    if [[ -z "$target_home" || ! -d "$target_home" ]]; then
        echo "failed to detect home directory for hiddify target user: $target_user"
        return 1
    fi

    install_root="${target_home}/Dropbox/bin"
    wrapper_path="${install_root}/hiddify.sh"
    app_dir="${install_root}/hiddify"
    installed_version="$(installed_version__hiddify "$target_home")"

    release_json="$(mktemp)"
    tmp_dir="$(mktemp -d)"
    backup_dir=""

    trap 'rm -f "$release_json"; rm -rf "$tmp_dir"; trap - RETURN' RETURN

    mkdir -p "$install_root" || return 1

    run_with_proxychains_fallback curl -fsSL "https://api.github.com/repos/hiddify/hiddify-app/releases/latest" -o "$release_json" || return 1

    latest_version="$(jq -r '.tag_name | ltrimstr("v")' "$release_json")"
    asset_url="$(
        jq -r '
            .assets[]
            | select(.name == "Hiddify-Linux-x64-AppImage.AppImage")
            | .browser_download_url
        ' "$release_json"
    )"
    asset_digest="$(
        jq -r '
            .assets[]
            | select(.name == "Hiddify-Linux-x64-AppImage.AppImage")
            | .digest // ""
            | sub("^sha256:"; "")
        ' "$release_json"
    )"

    if [[ -z "$latest_version" || -z "$asset_url" ]]; then
        echo "failed to resolve latest hiddify linux release asset"
        return 1
    fi

    if [[ -n "$installed_version" && "$installed_version" == "$latest_version" ]]; then
        echo "hiddify is already up to date ($installed_version)"
        return 0
    fi

    appimage_path="${tmp_dir}/Hiddify-Linux-x64-AppImage.AppImage"

    run_with_proxychains_fallback curl -fL --progress-bar "$asset_url" -o "$appimage_path" || return 1
    chmod +x "$appimage_path" || return 1

    if [[ -n "$asset_digest" ]]; then
        printf '%s  %s\n' "$asset_digest" "$appimage_path" | sha256sum -c - || return 1
    fi

    (
        cd "$tmp_dir" &&
        "$appimage_path" --appimage-extract >/dev/null
    ) || return 1

    extracted_dir="${tmp_dir}/squashfs-root"
    [[ -d "$extracted_dir" ]] || return 1

    if [[ -e "$app_dir" ]]; then
        backup_dir="${tmp_dir}/previous-hiddify"
        mv "$app_dir" "$backup_dir" || return 1
    fi

    if ! mv "$extracted_dir" "$app_dir"; then
        if [[ -n "$backup_dir" && -e "$backup_dir" ]]; then
            mv "$backup_dir" "$app_dir" || true
        fi
        return 1
    fi

    if [[ -n "$backup_dir" && -f "${backup_dir}/current-config.json" ]]; then
        cp -a "${backup_dir}/current-config.json" "${app_dir}/current-config.json" || return 1
    fi

    cat > "$wrapper_path" <<'EOF'
#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

exec "${DIR}/hiddify/hiddify" "$@"
EOF
    chmod +x "$wrapper_path" || return 1

    chown -R "${target_user}:${target_group}" "$app_dir" "$wrapper_path" || return 1
}

install__ly () {
    set -x

    cd /tmp/

    rm -rf /tmp/ly
    gclonecd https://codeberg.org/fairyglade/ly.git

    local latest_tag=$(git describe --tags --abbrev=0)
    if [ -n "$latest_tag" ]; then
        git checkout "$latest_tag"
    fi

    export PATH=/home/dmitry/Dropbox/bin/zig-x86_64-linux-0.15.2:$PATH

    zig build
    sudo env PATH="$PATH" zig build installexe -Dinit_system=systemd

    # sudo systemctl disable lightdm.service
    # sudo systemctl enable ly@tty2.service
    # sudo systemctl disable getty@tty2.service

    # sudo mkdir -p /usr/share/wayland-sessions
    # sudo tee /usr/share/wayland-sessions/sway.desktop << 'EOF'
    # [Desktop Entry]
    # Name=Sway
    # Comment=An i3-compatible Wayland compositor
    # Exec=sway
    # Type=Application
    # EOF
}
