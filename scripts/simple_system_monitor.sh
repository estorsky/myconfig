#!/bin/bash

set -e

DELAY=1m
LOG_FILE="$0.log"

trap 'gzip -f "${LOG_FILE}"; exit' INT

while true; do
    {
        uptime;
        free -m;
        ps aux --sort=-%cpu | head -n 10;
        printf "\n\n";
    } >> "${LOG_FILE}"

    sleep ${DELAY}
done
