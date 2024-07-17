#!/bin/bash

echo "Copying configuration files for $(basename "$PWD")"

LINK="https://github.com/neovim/neovim/releases/download/v0.9.5/nvim-linux64.tar.gz"
ARCHIVE_PATH="./output/archive.tar.xz"

# rm -rf ./output
# mkdir output

if [ ! -f "$ARCHIVE_PATH" ]; then
    mkdir output
    wget -q --show-progress $LINK -O $ARCHIVE_PATH
else
    echo "File already exists, skipping download."
fi
