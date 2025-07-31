#!/bin/bash

# set -x

source ~/myconfig/scripts/common_funcs.sh

get_curr_image_date() {
    eltex-vc list | awk '/curr_image_iss/ {print $NF, $(NF-1), $(NF-2)}' | sed 's/│//g' | xargs
}

download_curr_image() {
    wget http://validator.eltex.loc/checkerusers/dmitriy.privalov/files/curr_image_iss -O ~/shared/curr_image_iss
}

reboot_board() {
    board_iss_auto_enter_password.sh board_iss_firmware_install.sh
    notif "Reboot board"
}

DELAY=20

date=$(get_curr_image_date)
date_tmp=${date}

while true
do
    sleep ${DELAY}

    date_tmp=$(get_curr_image_date)

    if [ "$date" != "$date_tmp" ]; then
        date=$date_tmp

        download_curr_image
        reboot_board
    fi
done
