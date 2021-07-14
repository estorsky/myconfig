#!/bin/bash

IP=192.168.1.3

ssh board_root "tftp $IP -pl $1 -r $(basename $1)"

