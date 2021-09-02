#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $DIR/common_envs.sh

buffer () {
    maim -s | xclip -selection clipboard -t image/png
}

shared () {
    IP=$(ifconfig $COMMON_INTERFACE | \
        grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | \
        grep -Eo '([0-9]*\.){3}[0-9]*' | \
        grep -v '127.0.0.1')
    PORT="8887"
    DATE=$(date +%s)
    FILE_NAME="$DATE.png"
    DIR_PATH="/home/$USER/shared/screenshots/"
    FILE_PATH="$DIR_PATH/$FILE_NAME"
    LINK="http://$IP:$PORT/screenshots/$FILE_NAME"

    maim -s $FILE_PATH
    if [ $? -ne 0 ]; then
        exit
    fi

    echo $LINK | xclip -sel clip

    dunstify -u normal -t 10000 "$(basename $0)" "Link ($LINK) copied to buffer."
}

if [[ -n "$1"  ]]
then
    case "$1" in
        buffer) buffer; exit;;
        shared) shared; exit;;
        *) echo "$1 is not an option"; exit;;
    esac
else
    buffer
fi

