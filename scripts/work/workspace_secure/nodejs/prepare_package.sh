#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BIN_PATH="${DIR}/output/node-v20.15.1-linux-x64/bin"

echo "Extracting package"

cd output
tar xf archive.tar.xz
cd ..

cat <<EOL >> ../workspace_env.sh
export PATH=${BIN_PATH}:\$PATH
EOL
