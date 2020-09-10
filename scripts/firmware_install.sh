#!/bin/bash

FIRMWARE_PATH="/home/estor/tftp/firmware.stk"

if [ ! -f $FIRMWARE_PATH ]; then
    echo "firmware not exist"
    exit
fi

cat $FIRMWARE_PATH | ssh board_root 'cat > /firmware/primary_firmware/firmware.stk && reboot'

