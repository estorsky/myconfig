#!/bin/bash

convert () {
    NAME=$(youtube-dl -e $URL).mp3
    NAME=${NAME//\?/}
    NAME=${NAME//:/ -}
    youtube-dl -q -w --extract-audio --audio-format mp3 --output '%(title)s.%(ext)s' $URL 
    # ffmpeg -y -loglevel quiet -i "$NAME" -filter:a "atempo=1.25" "s${NAME}"
    # ./telegram-cli -W -D -e "send_audio Road './s${NAME}'" > /dev/null
    # rm "$NAME" "s${NAME}"
}

while true; do
    echo -n "URL: "
    read URL
    if [[ -z $URL ]]; then echo -n pls wait...; wait && echo done && exit; fi
    convert &
done

