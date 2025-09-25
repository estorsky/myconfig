#!/bin/bash

if [[ "$1" == "-l" ]]; then
    ~/myconfig/scripts/swaylock.sh
fi

if ! [ -d ~/work ] && ! pgrep -x remote-viewer > /dev/null; then
    systemctl suspend
fi
