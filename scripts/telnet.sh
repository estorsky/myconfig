#!/bin/bash

trap 'exit' INT

ret=0
ret_prev=0

if [[ -n "$1"  ]]; then
    while true 
    do
        ping $1 -c1 > /dev/null
        ret=$?
        if [ $ret -eq 0 ] && [ $ret_prev -ne 0 ]; then
            break
        fi
        ret_prev=$ret
        sleep 1
    done
    notify-send telnet "Trying connect to $1"
    telnet $1
else
    echo "IP needed"
fi

