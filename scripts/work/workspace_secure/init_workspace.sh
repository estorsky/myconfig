#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Iterate over each subdirectory and call its initialization script
for dir in "${DIR}"/*/ ; do
    if [ -d "$dir" ]; then
        echo "Initializing $(basename "${dir}")"
        # add check file exist
        (cd "$dir" && ./init_package.sh)
    fi
done

# Generate a file to be sourced in .bashrc
# echo "Generating environment setup script"
# cat <<EOL > workspace_env.sh
# # Generating file
# EOL

tar -czf "${DIR}/../workspace_secure.tar.gz" \
    -C "${DIR}/.." "$(basename "${DIR}")"
