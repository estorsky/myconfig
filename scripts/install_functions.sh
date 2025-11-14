#!/bin/bash

INSTALL_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
INSTALL_LINK="https://raw.githubusercontent.com/getsolus/3rd-party/master"

source "${INSTALL_DIR}/common_funcs.sh"

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

    cd /tmp/

    rm -rf /tmp/wl-clipboard
    gclonecd https://github.com/bugaevc/wl-clipboard.git
    meson build
    cd build
    sudo ninja install
}

install__rofi_wayland () {
    set -x

    cd /tmp/

    rm -rf /tmp/rofi-wayland
    gclonecd https://github.com/in0ni/rofi-wayland.git
    meson setup build
    ninja -C build
    sudo ninja -C build install
}

install__rofi_calc () {
    set -x

    cd /tmp/

    rm -rf /tmp/rofi-calc
    gclonecd https://github.com/svenstaro/rofi-calc.git

    if [ -f "${INSTALL_DIR}/../patches/rofi-calc/combi.patch" ]; then
        git apply "${INSTALL_DIR}/../patches/rofi-calc/combi.patch"
    fi

    export PKG_CONFIG_PATH=/usr/local/lib64/pkgconfig:$PKG_CONFIG_PATH
    meson setup build
    meson compile -C build/
    cd build
    sudo meson install
}

install__swaylock_effects () {
    set -x

    cd /tmp/

    rm -rf /tmp/swaylock-effects
    gclonecd https://github.com/jirutka/swaylock-effects.git
    meson build
    ninja -C build
    sudo ninja -C build install
}

# sudo usermod -a -G input "${USER}"
install__way_displays () {
    set -x

    cd /tmp/

    rm -rf /tmp/way-displays
    gclonecd https://github.com/alex-courtis/way-displays.git
    sudo make install
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

    sudo sed -i '/Exec/s/$/ --force-dark-mode --enable-features=VaapiVideoDecodeLinuxGL --use-gl=angle --use-angle=gl --disable-3d-apis --enable-unsafe-webgpu --enable-features=UseOzonePlatform --ozone-platform=wayland/' /usr/share/applications/google-chrome.desktop
    sudo sed -i '/Exec/s/$/ --force-dark-mode --enable-features=VaapiVideoDecodeLinuxGL --use-gl=angle --use-angle=gl --disable-3d-apis --enable-unsafe-webgpu --enable-features=UseOzonePlatform --ozone-platform=wayland/' /usr/share/applications/google-chrome-beta.desktop

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

# sudo eopkg it clang-devel fontconfig-devel cmake libxkbcommon-devel rust seatd-devel libinput-devel
install__asusctl () {
    set -x

    if ! is_asus_zephyrus_g14; then
        return 0
    fi

    cd /tmp/

    rm -rf /tmp/asusctl
    gclonecd https://gitlab.com/asus-linux/asusctl.git

    make
    sudo make install
    sudo systemctl daemon-reload
    sudo systemctl restart asusd
}

install__supergfxctl () {
    set -x

    if ! is_asus_zephyrus_g14; then
        return 0
    fi

    cd /tmp/

    rm -rf /tmp/supergfxctl
    gclonecd https://gitlab.com/asus-linux/supergfxctl.git

    make
    sudo make install

    sudo systemctl enable supergfxd.service --now
    sudo systemctl daemon-reload
    sudo systemctl restart asusd
}

