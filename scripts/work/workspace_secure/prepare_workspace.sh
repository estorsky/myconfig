#!/bin/bash

cat <<EOL > workspace_env.sh
# Generating file
EOL

# Iterate over each subdirectory and call its preparation script
for dir in */ ; do
    if [ -d "$dir" ]; then
        echo "Preparing $dir"
        (cd "$dir" && ./prepare_package.sh)
    fi
done
