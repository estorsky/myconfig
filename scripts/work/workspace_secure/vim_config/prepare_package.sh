#!/bin/bash

echo "Copying configuration files for $(basename "$PWD")"

# Define the output directory
OUTPUT_DIR="./output"
BACKUP_DIR=~/workspace_backup

# Ensure the output directory exists
if [ ! -d "$OUTPUT_DIR" ]; then
    echo "Output directory does not exist: $OUTPUT_DIR"
    exit 1
fi

# Ensure the backup directory exists
mkdir -p "$BACKUP_DIR"

# Copy old directories to backup
sudo cp -rL ~/.vim "$BACKUP_DIR/"
sudo cp -rL ~/.config/coc "$BACKUP_DIR/"
sudo cp -rL ~/.config/nvim "$BACKUP_DIR/"

# Copy directories from output to their respective locations
cp -rL "$OUTPUT_DIR/.vim" ~/
cp -rL "$OUTPUT_DIR/coc" ~/.config/
cp -rL "$OUTPUT_DIR/nvim" ~/.config/
