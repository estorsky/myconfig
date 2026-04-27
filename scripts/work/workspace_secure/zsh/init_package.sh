#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${DIR}/output"
SOURCE_DIR="${OUTPUT_DIR}/.oh-my-zsh"
TARGET_DIR="${HOME}/.oh-my-zsh"
BACKUP_DIR="${HOME}/workspace_backup/zsh/$(date '+%Y%m%d_%H%M%S')"

if [ ! -d "${SOURCE_DIR}" ]; then
    echo "Output directory does not exist: ${SOURCE_DIR}"
    exit 1
fi

mkdir -p "${BACKUP_DIR}"

if [ -e "${TARGET_DIR}" ]; then
    mv "${TARGET_DIR}" "${BACKUP_DIR}/"
fi

cp -aL "${SOURCE_DIR}" "${HOME}/"
