#!/bin/bash

PROJECT_NAME=$(basename `git rev-parse --show-toplevel`)
COMPILE_COMMANDS="compile_commands.json"
OPT="/var/lib/docker/volumes/${PROJECT_NAME}_opt/_data"
GCC="rtk-ms-2.0.0-linux-gcc"
GCC_PATH="${OPT}/rtk-ms-2.0.0-linux-mips-3.18-4.8.5-u0.9.33-toolchain/bin/${GCC}"

sed -i -e "s~\"${GCC}~\"${GCC_PATH}~g" ${COMPILE_COMMANDS}
sed -i -e "s~/home/user/projects/~/home/estor/projects/${PROJECT_NAME}/~g" ${COMPILE_COMMANDS}
sed -i -e "s~/opt~${OPT}~g" ${COMPILE_COMMANDS}
