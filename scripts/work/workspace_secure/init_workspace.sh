#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILE="${DIR}/workspace_env.sh"

source "${DIR}/lib.sh"

workspace_secure_prepare_env_file "${ENV_FILE}"

for dir in "${DIR}"/*/ ; do
    if [ ! -x "${dir}/init_package.sh" ]; then
        continue
    fi

    workspace_secure_log "Initializing $(basename "${dir}")"
    (cd "${dir}" && ./init_package.sh)
done
