#!/bin/bash

set -e

trap 'exit' INT

LINK="https://raw.githubusercontent.com/getsolus/3rd-party/master"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/common_funcs.sh

run_with_root $1

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
    cmake ..
    make

    make install

    cd /tmp/

    ln -sf /usr/local/bin/xkb-switch /usr/bin/xkb-switch
}

install__google_chrome () {
    sudo eopkg bi --ignore-safety $LINK/network/web/browser/google-chrome-stable/pspec.xml
    sudo eopkg it google-chrome-*.eopkg;sudo rm google-chrome-*.eopkg
}

install__spotify () {
    sudo eopkg bi --ignore-safety $LINK/multimedia/music/spotify/pspec.xml
    sudo eopkg it spotify*.eopkg;sudo rm spotify*.eopkg
}

install__sublime_text_3 () {
    sudo eopkg bi --ignore-safety $LINK/programming/sublime-text-3/pspec.xml
    sudo eopkg it sublime*.eopkg;sudo rm sublime*.eopkg
}

install__team_viewer () {
    sudo eopkg bi --ignore-safety $LINK/network/util/teamviewer/pspec.xml
    sudo eopkg it teamviewer*.eopkg; sudo rm teamviewer*.eopkg
    sudo systemctl start teamviewerd.service
}

install__ms_fonts () {
    sudo eopkg bi --ignore-safety $LINK/desktop/font/mscorefonts/pspec.xml
    sudo eopkg it mscorefonts*.eopkg;sudo rm mscorefonts*.eopkg
}

init () {
    cd $DIR

    sudo eopkg up -y

    sudo eopkg it -y screenfetch telegram nautilus-dropbox git vim tmux vlc \
        htop zsh rofi linux-lts-headers make gcc g++ gnome-tweaks \
        simplenote llvm-clang gdb mc ncdu calibre gimp nodejs man-pages \
        linux-current-headers lm_sensors qbittorrent wireshark xkill \
        neovim mtr python3-ipython i3lock krita ranger cmus cava etcher \
        speedtest-cli cmatrix highlight curl-gnutls iotop iftop sshfs-fuse \
        glances feh gnuplot shellcheck kdeconnect translate-shell rsync thunderbird \
        openvpn intel-microcode i3blocks i3 compton lxappearance dunst kitty \
        xsel docker pidgin pavucontrol doxygen cppcheck font-awesome-ttf \
        net-snmp expect qemu dnsmasq openssh-server xev openjdk-8 \
        ghex picocom golang nmap maim fzf fd

    # Deleted from repository: albert
    # Optional: bat

    # sudo eopkg it iw aircrack-ng libpcap-devel hashcat bzip2-devel
    sudo eopkg it -y -c system.devel
    sudo eopkg it -y silver-searcher ctags ripgrep  # for vim
    sudo eopkg remove -y firefox hexchat transmission

    sudo pip3 install eopkg3p

    gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space', '<Alt>Shift_L']"
    gsettings set org.gnome.desktop.input-sources xkb-options "['ctrl:nocaps']"

    # autostart unit
    # sudo cp ../../.myconfig/systemd/autostart_root.service /etc/systemd/system/
    # systemctl enable autostart_root.service
    # systemctl start autostart_root.service
    # systemctl status autostart_root.service
    # sudo chattr +i ../../.myconfig/scripts/autostart_root.sh

    # lockscreen unit
    # sudo cp ../../myconfig/systemd/lockscreen.service /etc/systemd/system/
    # systemctl enable lockscreen.service
    # systemctl start lockscreen.service
    # systemctl status lockscreen.service

    install__google_chrome
    install__spotify
    install__sublime_text_3
    install__ms_fonts
    install__xkb_switch i3

    go get github.com/gcla/termshark/v2/cmd/termshark
    # go get github.com/sorenisanerd/gotty
}

update () {
    sudo eopkg up -y
    sudo eopkg3p up -y
    install__xkb_switch i3
}

clean () {
    sudo eopkg delete-cache
    sudo eopkg3p delete-cache
}

if [[ -n "$1" ]]
then
    case "$1" in
        init) check_connection; init; exit;;
        up) check_connection; update; exit;;
        clean) clean; exit;;
        * ) echo "$1 is not an option"
            exit;;
    esac
fi

echo -e "params: init, up, clean"

