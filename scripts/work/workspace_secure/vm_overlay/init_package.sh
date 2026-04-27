#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGE_DIR="${DIR}/output/overlay"
FILES_DIR="${PACKAGE_DIR}/files"
TARGET_DIR="${HOME}/myconfig"
BACKUP_ROOT="${HOME}/workspace_backup/vm_overlay"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
RUN_BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
LOG_FILE="${RUN_BACKUP_DIR}/apply.log"

source "${DIR}/../lib.sh"

if [ ! -d "${PACKAGE_DIR}" ]; then
    echo "Overlay package directory does not exist: ${PACKAGE_DIR}"
    exit 1
fi

if [ ! -d "${TARGET_DIR}" ]; then
    echo "Target myconfig directory does not exist: ${TARGET_DIR}"
    exit 1
fi

mkdir -p "${RUN_BACKUP_DIR}"
touch "${LOG_FILE}"

if [ -d "${FILES_DIR}" ]; then
    workspace_secure_log "Applying overlay files" | tee -a "${LOG_FILE}"
    workspace_secure_copy_tree "${FILES_DIR}" "${TARGET_DIR}"
fi
