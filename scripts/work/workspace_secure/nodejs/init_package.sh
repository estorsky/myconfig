#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PACKAGE_DIR="${DIR}/output/package"
BIN_PATH="${PACKAGE_DIR}/bin"
ENV_FILE="${DIR}/../workspace_env.sh"

source "${DIR}/../lib.sh"

if [ ! -x "${BIN_PATH}/node" ]; then
    echo "Portable nodejs package was not prepared: ${BIN_PATH}/node"
    exit 1
fi

workspace_secure_append_env_path "${ENV_FILE}" "${BIN_PATH}" "nodejs"
