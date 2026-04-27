#!/bin/bash

set -euo pipefail

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
OUTPUT_DIR="${DIR}/output"
SOURCE_DIR="${HOME}/.oh-my-zsh"

if [ ! -d "${SOURCE_DIR}" ]; then
    echo "Directory does not exist: ${SOURCE_DIR}"
    exit 1
fi

rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

cp -aL "${SOURCE_DIR}" "${OUTPUT_DIR}/"
