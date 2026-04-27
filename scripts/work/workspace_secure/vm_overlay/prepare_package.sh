#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${DIR}/output"
OVERLAY_SOURCE_DIR="$(cd "${DIR}/../../workspace_secure_overlay" && pwd)"
PACKAGE_DIR="${OUTPUT_DIR}/overlay"
FILES_SOURCE_DIR="${OVERLAY_SOURCE_DIR}/files"

source "${DIR}/../lib.sh"

workspace_secure_reset_dir "${OUTPUT_DIR}"
mkdir -p "${PACKAGE_DIR}"

if [ -d "${FILES_SOURCE_DIR}" ]; then
    workspace_secure_log "Packing VM overlay files from ${FILES_SOURCE_DIR}"
    workspace_secure_copy_tree "${FILES_SOURCE_DIR}" "${PACKAGE_DIR}/files"
fi
