#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Copying configuration files for $(basename "$PWD")"

LINK="https://nodejs.org/dist/v20.15.1/node-v20.15.1-linux-x64.tar.xz"
ARCHIVE_PATH="./output/archive.tar.xz"

# rm -rf ./output
# mkdir output

if [ ! -f "$ARCHIVE_PATH" ]; then
    mkdir output
    wget -q --show-progress $LINK -O $ARCHIVE_PATH
else
    echo "File already exists, skipping download."
fi
