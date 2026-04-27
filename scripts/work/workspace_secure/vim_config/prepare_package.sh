#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${DIR}/output"

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

if [ -d "${HOME}/.vim" ]; then
    cp -aL "${HOME}/.vim" "${OUTPUT_DIR}/"
fi

if [ -d "${HOME}/.config/coc" ]; then
    cp -aL "${HOME}/.config/coc" "${OUTPUT_DIR}/"
fi

if [ -d "${HOME}/.config/nvim" ]; then
    cp -aL "${HOME}/.config/nvim" "${OUTPUT_DIR}/"
fi
