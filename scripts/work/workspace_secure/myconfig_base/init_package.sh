#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${DIR}/output"
PACKAGE_DIR="${OUTPUT_DIR}/myconfig"
TARGET_DIR="${HOME}/myconfig"
BACKUP_ROOT="${HOME}/workspace_backup/myconfig_base"
STAGING_ROOT="${HOME}/.cache/workspace_secure"
TIMESTAMP="$(date '+%Y%m%d_%H%M%S')"
BACKUP_DIR="${BACKUP_ROOT}/${TIMESTAMP}"
LOCAL_DIFF_FILE="${BACKUP_DIR}/local_changes.patch"
REAPPLY_LOG_FILE="${BACKUP_DIR}/reapply.log"
LOCAL_UNTRACKED_FILE="${BACKUP_DIR}/untracked_files.txt"

source "${DIR}/../lib.sh"

if [ ! -d "${PACKAGE_DIR}" ]; then
    echo "Package directory does not exist: ${PACKAGE_DIR}"
    exit 1
fi

mkdir -p "${BACKUP_DIR}"
mkdir -p "${STAGING_ROOT}"

STAGING_DIR="$(mktemp -d "${STAGING_ROOT}/myconfig_base.XXXXXX")"
trap 'rm -rf "${STAGING_DIR}"' EXIT

workspace_secure_log "Preparing staged myconfig tree"
mkdir -p "${STAGING_DIR}/myconfig"
workspace_secure_copy_tree "${PACKAGE_DIR}" "${STAGING_DIR}/myconfig"

if [ -d "${TARGET_DIR}" ]; then
    workspace_secure_log "Backing up existing myconfig to ${BACKUP_DIR}"

    if [ -d "${TARGET_DIR}/.git" ]; then
        git -C "${TARGET_DIR}" status --short > "${BACKUP_DIR}/git_status.txt" || true
        git -C "${TARGET_DIR}" diff --binary HEAD > "${LOCAL_DIFF_FILE}" || true
        git -C "${TARGET_DIR}" ls-files --others --exclude-standard > "${LOCAL_UNTRACKED_FILE}" || true
    fi

    mv "${TARGET_DIR}" "${BACKUP_DIR}/previous_myconfig"
fi

workspace_secure_log "Installing staged myconfig into ${TARGET_DIR}"
mv "${STAGING_DIR}/myconfig" "${TARGET_DIR}"

apply_patch_file() {
    local patch_path="$1"
    local label="$2"

    if [ ! -s "${patch_path}" ]; then
        return
    fi

    workspace_secure_log "Trying to apply ${label}" | tee -a "${REAPPLY_LOG_FILE}"

    if ! git -C "${TARGET_DIR}" apply --check --whitespace=nowarn "${patch_path}" \
        >> "${REAPPLY_LOG_FILE}" 2>&1; then
        workspace_secure_log "${label} could not be applied; inspect ${patch_path}" \
            | tee -a "${REAPPLY_LOG_FILE}"
        return
    fi

    if git -C "${TARGET_DIR}" apply --whitespace=nowarn "${patch_path}" \
        >> "${REAPPLY_LOG_FILE}" 2>&1; then
        workspace_secure_log "${label} applied successfully" | tee -a "${REAPPLY_LOG_FILE}"
    else
        workspace_secure_log "${label} failed during apply; inspect ${patch_path}" \
            | tee -a "${REAPPLY_LOG_FILE}"
    fi
}

touch "${REAPPLY_LOG_FILE}"
apply_patch_file "${LOCAL_DIFF_FILE}" "previous VM diff"
