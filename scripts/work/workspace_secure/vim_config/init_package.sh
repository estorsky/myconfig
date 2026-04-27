#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${DIR}/output"
BACKUP_DIR="${HOME}/workspace_backup/vim_config/$(date '+%Y%m%d_%H%M%S')"

mkdir -p "${BACKUP_DIR}"
mkdir -p "${HOME}/.config"

if [ -d "${HOME}/.vim" ]; then
    mv "${HOME}/.vim" "${BACKUP_DIR}/"
fi

if [ -d "${HOME}/.config/coc" ]; then
    mv "${HOME}/.config/coc" "${BACKUP_DIR}/"
fi

if [ -d "${HOME}/.config/nvim" ]; then
    mv "${HOME}/.config/nvim" "${BACKUP_DIR}/"
fi

if [ -d "${OUTPUT_DIR}/.vim" ]; then
    cp -aL "${OUTPUT_DIR}/.vim" "${HOME}/"
fi

if [ -d "${OUTPUT_DIR}/coc" ]; then
    cp -aL "${OUTPUT_DIR}/coc" "${HOME}/.config/"
fi

if [ -d "${OUTPUT_DIR}/nvim" ]; then
    cp -aL "${OUTPUT_DIR}/nvim" "${HOME}/.config/"
fi
