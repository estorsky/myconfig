#!/bin/bash

if [ "$XDG_SESSION_TYPE" = wayland ]
then
    wl-copy
else
    xclip -in -selection clipboard
fi
