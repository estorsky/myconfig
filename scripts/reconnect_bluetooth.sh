#!/bin/bash

DEVICE_ADDRESS="80:99:E7:FF:97:E2"

bluetoothctl disconnect $DEVICE_ADDRESS
# sleep 2
bluetoothctl connect $DEVICE_ADDRESS
