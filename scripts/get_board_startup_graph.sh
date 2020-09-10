#!/bin/bash

IP=192.168.1.3

ssh board_root "systemd-analyze plot >bootup.svg && tftp $IP -pl bootup.svg"

