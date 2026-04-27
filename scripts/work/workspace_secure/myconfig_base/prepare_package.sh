#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${DIR}/output"
PACKAGE_DIR="${OUTPUT_DIR}/myconfig"
EXCLUDES_FILE="${DIR}/excludes.txt"
REPO_ROOT="$(cd "${DIR}/../../../.." && pwd)"
MANIFEST_FILE="${OUTPUT_DIR}/manifest.env"
HOST_DIFF_FILE="${OUTPUT_DIR}/host_changes.patch"
HOST_STATUS_FILE="${OUTPUT_DIR}/host_git_status.txt"
HOST_UNTRACKED_FILE="${OUTPUT_DIR}/host_untracked_files.txt"

source "${DIR}/../lib.sh"

workspace_secure_reset_dir "${OUTPUT_DIR}"
mkdir -p "${PACKAGE_DIR}"

workspace_secure_log "Packing myconfig from ${REPO_ROOT}"
rsync -a --delete \
    --exclude-from="${EXCLUDES_FILE}" \
    "${REPO_ROOT}/" "${PACKAGE_DIR}/"

if git -C "${REPO_ROOT}" rev-parse --verify HEAD >/dev/null 2>&1; then
    git -C "${REPO_ROOT}" status --short > "${HOST_STATUS_FILE}" || true
    git -C "${REPO_ROOT}" diff --binary HEAD > "${HOST_DIFF_FILE}" || true
    git -C "${REPO_ROOT}" ls-files --others --exclude-standard > "${HOST_UNTRACKED_FILE}" || true
fi

{
    echo "package_name=myconfig_base"
    echo "source_repo=${REPO_ROOT}"

    if git -C "${REPO_ROOT}" rev-parse --verify HEAD >/dev/null 2>&1; then
        echo "git_head=$(git -C "${REPO_ROOT}" rev-parse HEAD)"
        echo "git_branch=$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref HEAD)"
        if [ -n "$(git -C "${REPO_ROOT}" status --short)" ]; then
            echo "git_dirty=true"
        else
            echo "git_dirty=false"
        fi
    fi
} > "${MANIFEST_FILE}"
