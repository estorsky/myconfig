#!/bin/bash

FIRMWARE_LOCAL_PATH="/home/estor/shared/firmware.stk"
# FIRMWARE_LOCAL_PATH="/home/estor/shared/firmwares/ltp-16n-1.2.0-build491.fw.bin"

if [ ! -f $FIRMWARE_LOCAL_PATH ]; then
    echo "firmware not exist"
    exit
fi

cat $FIRMWARE_LOCAL_PATH | ssh board_root 'cat > /firmware/primary_firmware/firmware.stk && reboot'

