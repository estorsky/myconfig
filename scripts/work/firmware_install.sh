#!/bin/bash

FIRMWARE_LOCAL_PATH="/home/estor/shared/firmware.stk"

if [ ! -f $FIRMWARE_LOCAL_PATH ]; then
    echo "firmware not exist"
    exit
fi

cat $FIRMWARE_LOCAL_PATH | ssh board_root 'cat > /firmware/primary_firmware/firmware.stk && reboot'

