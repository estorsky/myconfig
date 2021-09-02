#!/bin/bash

start_qemu () {
    cd ~/projects/$1/firmware/scripts

    while true; do
        ./run_qemu.sh
        if [ $? -ne 0 ]; then
            echo "Failed, aborting."
            exit 1
        fi
        sleep 2
    done
}

restart_qemu () {
    pkill qemu-system-x86
}

kill_yourself () {
    pkill qemu-system-x86
	killall $(basename $0)
}

case "$1" in
    s1) start_qemu "ltp-n_1"
        exit;;
    s2) start_qemu "ltp-n_2"
        exit;;
    s3) start_qemu "ltp-n_3"
        exit;;
    r) restart_qemu
        exit;;
    k) kill_yourself
        exit;;
    *? ) echo "bad arg '$1'"
        exit;;
esac

