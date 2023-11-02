#!/bin/bash

FLAG__PIPE=false

params () {
    case "$1" in
        -p) FLAG__PIPE=true ;;
        * ) echo "$1 unknown option"
            exit 0;;
    esac
}

# check flags
for i in "$@"
do
    params $i
done

if [ "$FLAG__PIPE" = true ]
then
    text=`cat`
else
    if [ "$XDG_SESSION_TYPE" = wayland ]
    then
        text=$(wl-paste --primary)
    else
        # text=$(xclip -selection primary -o)
        text=$(xsel -o)
    fi
fi

# some transform text
text=${text//=/ }
text=${text//"'"/ }
text=${text//// }
# text=${text//\n/ }
text=${text//-/ }
# text="$(echo $text | xargs)"

text_code="$(trans -identify "$text" | grep Code | awk '{print $2}' | \
    sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2})?)?[mGK]//g")" # rm formatting
target_text_code="en"

if [ "$text_code" == "en" ]; then
    target_text_code="ru"
else
    target_text_code="en"
fi

trans_text="$(trans -b "$text" -t $target_text_code)"

if [ "$trans_text" ]; then
    # notify-send "$(basename $0)" "$trans_text"
    dunstify -u low -t 20000 -r 1 "$(basename $0)" "$trans_text"
fi

