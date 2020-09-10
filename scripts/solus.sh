#!/bin/bash

trap 'exit' INT

if [[ $(id -u) -ne 0 ]]; then
    sudo $0 $1
    exit
fi

check_connection () {
    echo -n "Checking internet connection..."
    wget -q --spider http://google.com
    if [ $? -ne 0 ]; then
        echo "off"
        exit
    else
        echo "on"
    fi
}

LINK="https://raw.githubusercontent.com/getsolus/3rd-party/master"
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

init () {
    cd $DIR

    # sudo eopkg up
    sudo eopkg it -y screenfetch telegram nautilus-dropbox git vim tmux vlc \
        htop zsh albert linux-lts-headers make gcc g++ gnome-tweaks \
        simplenote llvm-clang gdb mc ncdu calibre gimp nodejs man-pages \
        linux-current-headers lm_sensors qbittorrent wireshark xkill \
        neovim mtr python3-ipython i3lock krita ranger cmus cava etcher \
        speedtest-cli cmatrix highlight curl-gnutls iotop iftop sshfs-fuse \
        glances feh gnuplot shellcheck kdeconnect translate-shell rsync thunderbird \
        openvpn intel-microcode i3blocks i3 compton lxappearance dunst kitty \
        xsel docker pidgin pavucontrol doxygen cppcheck font-awesome-ttf \
        ripgrep net-snmp expect qemu dnsmasq openssh-server xev openjdk-8 \
        ghex picocom golang
    # sudo eopkg it iw aircrack-ng libpcap-devel hashcat bzip2-devel
    sudo eopkg it -y -c system.devel
    sudo eopkg it -y silver-searcher ctags fzf # for vim
    sudo eopkg remove -y firefox hexchat transmission

    # gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['<Super>space', '<Alt>Shift_L']"
    # gsettings set org.gnome.desktop.input-sources xkb-options "['ctrl:nocaps']"

    # autostart unit
    # sudo cp ../../.myconfig/systemd/autostart_root.service /etc/systemd/system/
    # systemctl enable autostart_root.service
    # systemctl start autostart_root.service
    # systemctl status autostart_root.service
    # sudo chattr +i ../../.myconfig/scripts/autostart_root.sh

    # lockscreen unit
    # sudo cp ../../.myconfig/systemd/lockscreen.service /etc/systemd/system/
    # systemctl enable lockscreen.service
    # systemctl start lockscreen.service
    # systemctl status lockscreen.service

    # Google Chrome
    sudo eopkg bi --ignore-safety $LINK/network/web/browser/google-chrome-stable/pspec.xml
    sudo eopkg it google-chrome-*.eopkg;sudo rm google-chrome-*.eopkg

    # Spotify
    sudo eopkg bi --ignore-safety $LINK/multimedia/music/spotify/pspec.xml
    sudo eopkg it spotify*.eopkg;sudo rm spotify*.eopkg

    # Sublime Text 3
    sudo eopkg bi --ignore-safety $LINK/programming/sublime-text-3/pspec.xml
    sudo eopkg it sublime*.eopkg;sudo rm sublime*.eopkg

    # TeamViewer
    # sudo eopkg bi --ignore-safety $LINK/network/util/teamviewer/pspec.xml
    # sudo eopkg it teamviewer*.eopkg; sudo rm teamviewer*.eopkg
    # sudo systemctl start teamviewerd.service

    # Fonts
    sudo eopkg bi --ignore-safety $LINK/desktop/font/mscorefonts/pspec.xml
    sudo eopkg it mscorefonts*.eopkg;sudo rm mscorefonts*.eopkg
}

update () {
    sudo eopkg -y up

    # VIM
    # sudo -u estor vi +PlugUpdate +qa && echo "vim is updated!"

    # Google Chrome
    if eopkg li | grep -q google-chrome; then
        sudo eopkg bi --ignore-safety $LINK/network/web/browser/google-chrome-stable/pspec.xml
        sudo eopkg it google-chrome-*.eopkg;sudo rm google-chrome-*.eopkg
    fi

    # Spotify
    if eopkg li | grep -q spotify; then
        sudo eopkg bi --ignore-safety $LINK/multimedia/music/spotify/pspec.xml
        sudo eopkg it spotify*.eopkg;sudo rm spotify*.eopkg
    fi

    # Sublime Text 3
    if eopkg li | grep -q sublime; then
        sudo eopkg bi --ignore-safety $LINK/programming/sublime-text-3/pspec.xml
        sudo eopkg it sublime*.eopkg;sudo rm sublime*.eopkg
    fi

    # TeamViewer
    # if eopkg li | grep -q teamviewer; then
        # sudo eopkg bi --ignore-safety $LINK/network/util/teamviewer/pspec.xml
        # sudo eopkg it teamviewer*.eopkg; sudo rm teamviewer*.eopkg
        # sudo systemctl start teamviewerd.service
    # fi
}

clean () {
    sudo eopkg delete-cache
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

