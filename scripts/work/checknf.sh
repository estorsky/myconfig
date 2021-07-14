#!/bin/bash

if [[ -z "$1" ]]; then
    echo "pls full path in arg"
    exit
fi

ret=0

cd $1
ret=$?
if [ $ret -ne 0 ]; then
    exit
fi

LASTCRF=$(ls -ti | head -1)
LASTCHA=$(stat -c '%z' $(echo $LASTCRF | cut -d " " -f2-))

while true
do
    tLASTCRF=$(ls -ti | head -1)
    # echo $tLASTCRF
    tLASTCHA=$(stat -c '%z' $(echo $LASTCRF | cut -d " " -f2-))
    # echo $tLASTCHA
    if [ "$tLASTCRF" != "$LASTCRF" ] || [ "$tLASTCHA" != "$LASTCHA" ]; then
        LASTCRF=$tLASTCRF
        LASTCHA=$(stat -c '%z' $(echo $LASTCRF | cut -d " " -f2-))
        FILENAME=$(echo $LASTCRF | cut -d " " -f2-)
        # echo $LASTCRF
        # echo $LASTCHA
        # echo $FILENAME
        if [[ $FILENAME == *"firmware"* ]]; then

            # IP="$(ifconfig -i enp1s0 | grep -Eo 'inet (addr:)?([0-9]*\.){3}[0-9]*' | \
                # grep -Eo '([0-9]*\.){3}[0-9]*')"

            # STRING="copy tftp://$IP/$FILENAME fs://firmware"
            # echo $STRING | xclip -sel clip

            dunstify -u normal -t 10000 -r 3 "$(basename $0)" "New file in $(basename $1) '$FILENAME'"

            # sleep 1
# 
            # dunstify -u low -t 10000 -r 4 "$(basename $0)" "string '$STRING' copy to clipboard"
        # else
            # # notify-send $(basename $0) "new file in $(basename $1) '$(echo $LASTCRF | cut -d " " -f2-)'"
            # dunstify -u normal -t 10000 -r 3 "$(basename $0)" "New file in $(basename $1) '$FILENAME'"
        fi
    fi
    sleep 5
done

