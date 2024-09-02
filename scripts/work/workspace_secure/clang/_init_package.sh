#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo "Copying configuration files for $(basename "$PWD")"

# https://github.com/llvm/llvm-project/releases
LINK="https://github.com/llvm/llvm-project/releases/download/llvmorg-18.1.8/clang+llvm-18.1.8-x86_64-linux-gnu-ubuntu-18.04.tar.xz"
BIN_PATH="${DIR}/output/clang+llvm-18.1.8-x86_64-linux-gnu-ubuntu-18.04/bin"
ARCHIVE_PATH="./output/archive.tar.xz"

# rm -rf ./output
# mkdir output

if [ ! -f "$ARCHIVE_PATH" ]; then
    mkdir output
    wget -q --show-progress $LINK -O $ARCHIVE_PATH
else
    echo "File already exists, skipping download."
fi
