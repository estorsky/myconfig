#!/bin/bash

PROJECT_NAME=$(basename `git rev-parse --show-toplevel`)
PROJECT_PATH="/home/${USER}/projects/${PROJECT_NAME}/"
COMPILE_COMMANDS="compile_commands.json"
OPT_PATH="/var/lib/docker/volumes/${PROJECT_NAME}_opt/_data"
GCC="rtk-ms-2.0.0-linux-gcc"
GCC_PATH="${OPT_PATH}/rtk-ms-2.0.0-linux-mips-3.18-4.8.5-u0.9.33-toolchain/bin/${GCC}"

sed -i -e "s~\"${GCC}~\"${GCC_PATH}~g" ${COMPILE_COMMANDS}
sed -i -e "s~/home/user/projects/~${PROJECT_PATH}~g" ${COMPILE_COMMANDS}
sed -i -e "s~/opt~${OPT_PATH}~g" ${COMPILE_COMMANDS}
