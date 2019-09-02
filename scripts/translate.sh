#!/bin/bash

# text=$(xclip -selection primary -o)
text=$(xsel -o)
trans=$(trans -b "$text" -t ru)
if [ "$trans" ]; then
    # notify-send "$trans"
    dunstify -u low -t 20000 -r 1 "$trans"
fi

