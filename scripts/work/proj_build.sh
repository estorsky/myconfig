#!/bin/bash

MY_ECHO=true

source ~/myconfig/scripts/common_funcs.sh

check_git

set -o pipefail
# trap 'exit' INT

TFTP_FOLDER="/home/estor/shared"
FIRMWARE_NAME="firmware.stk"
LOG_FILE="./build.log"
PROJECT_NAME=$(basename `git rev-parse --show-toplevel`)

FLAG__AUTO_INSTALL=false
FLAG__FULL_BUILD=false
FLAG__BEAR=false
FLAG__REBOOT=false


ltpn () {
    if [ "$FLAG__FULL_BUILD" = true ]
    then
        flags="-f"
    fi

    # build
    dockerun.sh $PROJECT_NAME -c "./build.sh -q $flags" 2>&1 | tee $LOG_FILE
    notif_check $? "[$PROJECT_NAME] build done!" "[$PROJECT_NAME] build fail!"

    # copy to tftp folder
    firmware_path=$(cat $LOG_FILE | grep "Opening STK file")
    firmware_path=${firmware_path#*projects/}
    firmware_path=$(dirname $firmware_path)
    firmware_path="$(pwd)/$firmware_path/$FIRMWARE_NAME"
    rm $LOG_FILE

    cp "$firmware_path" "$TFTP_FOLDER/$FIRMWARE_NAME"
    notif_check $? "[$PROJECT_NAME] firmware copied successfully!" \
        "[$PROJECT_NAME] firmware copy fail!"

    # install on board
    if [ "$FLAG__AUTO_INSTALL" = true ]
    then
        board_auto_enter_password.sh board_firmware_install.sh
        notif_check $? "[$PROJECT_NAME] firmware install successfully!" \
            "[$PROJECT_NAME] firmware install fail!"
    elif [ "$FLAG__REBOOT" = true ]
    then
        board_auto_enter_password.sh board_reboot.sh
        notif_check $? "[$PROJECT_NAME] board rebooted successfully!" \
            "[$PROJECT_NAME] board rebooted fail!"
    fi
}

iss () {
    notif "[$PROJECT_NAME] build started"

    # build
    if ! [ "$FLAG__BEAR" = true ]
    then
        # dockerun.sh $PROJECT_NAME -c "./build_9300.sh -C -R" 2>&1 | tee $LOG_FILE
        dockerun.sh $PROJECT_NAME -c "./build_9300.sh" 2>&1 | tee $LOG_FILE
        # dockerun.sh $PROJECT_NAME -c "./build_9300.sh -R" 2>&1 | tee $LOG_FILE
        notif_check $? "[$PROJECT_NAME] build done!" "[$PROJECT_NAME] build fail!"
    else
        # git clean -fdx
        dockerun.sh $PROJECT_NAME -c "bear ./build_9300.sh" 2>&1 | tee $LOG_FILE
        notif_check $? "[$PROJECT_NAME] build done!" "[$PROJECT_NAME] build fail!"
        realtek_iss_bear_replace.sh
        notif_check $? "[$PROJECT_NAME] replace paths done!" "[$PROJECT_NAME] replace paths fail!"
    fi


    # fix this
    # copy to tftp folder
    firmware_path="./image/curr_image_iss"
    rm $LOG_FILE

    cp "$firmware_path" "$TFTP_FOLDER/curr_image_iss"
    notif_check $? "[$PROJECT_NAME] firmware copied successfully!" \
        "[$PROJECT_NAME] firmware copy fail!"

    # install on board
    if [ "$FLAG__AUTO_INSTALL" = true ]
    then
        board_iss_auto_enter_password.sh board_iss_firmware_install.sh
        notif_check $? "[$PROJECT_NAME] firmware install successfully!" \
            "[$PROJECT_NAME] firmware install fail!"
    elif [ "$FLAG__REBOOT" = true ]
    then
        board_iss_auto_enter_password.sh board_iss_firmware_install.sh
        notif_check $? "[$PROJECT_NAME] board rebooted successfully!" \
            "[$PROJECT_NAME] board rebooted fail!"
    fi
}


params () {
    case "$1" in
        -a) FLAG__AUTO_INSTALL=true ;;
        -f) FLAG__FULL_BUILD=true ;;
        -r) FLAG__REBOOT=true ;;
        -b) FLAG__BEAR=true ;;
        * ) echo "$1 is not an option"
            exit 3;;
    esac
}

# check flags
for i in "$@"
do
    params $i
done

# check proj
if git config --get remote.origin.url | grep "ltp-n"
then
    ltpn
    exit 0;
elif git config --get remote.origin.url | grep "ltp-x"
then
    echo "ltp-x not supported"
    exit 0
elif git config --get remote.origin.url | grep "realtek_iss"
then
    iss
    exit 0
else
    echo "unknown proj"
fi

