#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source "${DIR}/lib.sh"

for dir in "${DIR}"/*/ ; do
    if [ ! -x "${dir}/prepare_package.sh" ]; then
        continue
    fi

    workspace_secure_log "Preparing $(basename "${dir}")"
    (cd "${dir}" && ./prepare_package.sh)
done

workspace_secure_log "Creating workspace bundle archive"
tar -czf "${DIR}/../workspace_secure.tar.gz" \
    -C "${DIR}/.." "$(basename "${DIR}")"
