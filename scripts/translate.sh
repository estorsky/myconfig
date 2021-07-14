#!/bin/bash

FLAG__PIPE=false

params () {
    case "$1" in
        -p) FLAG__PIPE=true ;;
        * ) echo "$1 is not an option"
            exit 3;;
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
    # text=$(xclip -selection primary -o)
    text=$(xsel -o)
    text=${text//=/ }
    text=${text//"'"/ }
    text=${text//// }
    text=${text//\n/ }
    text=${text//-/ }
    # text="$(echo $text | xargs)"
fi

trans=$(trans -b "$text" -t ru)

if [ "$trans" ]; then
    # notify-send "$trans"
    dunstify -u low -t 20000 -r 1 "$(basename $0)" "$trans"
fi

