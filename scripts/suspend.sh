#!/bin/bash

if [[ "$1" == "-l" ]]; then
    ~/myconfig/scripts/swaylock.sh
fi

if ! [ -d ~/work ]; then
    systemctl suspend
fi
