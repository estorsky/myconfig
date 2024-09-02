#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# echo $DIR

echo "Copying configuration files for $(basename "$PWD")"

rm -rf ./output
mkdir output

# Copy directories to output
cp -rL ~/.vim ./output/
cp -rL ~/.config/coc ./output/
cp -rL ~/.config/nvim ./output/
