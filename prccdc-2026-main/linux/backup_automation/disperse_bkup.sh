#!/usr/bin/env bash

set -euo pipefail

# shell script to zip a backup directory, bak, to various locations on linux system
# must be ran where /bak is
# living document; update as needed
# last updated: 1-29-2026, dangjam

# begin script only if ./bak is found
if [ -d "./bak" ]; then
    # zip up backup folder
    tar -zcvf bak_bak.tar.gz ./bak

    src_file="bak_bak.tar.gz"

    backup_dirs=(
        "/..."
        "/var/log/..."
    )

    # continue only if backup tar exists
    if [[ ! -f "$src_file" ]]; then
        echo "Error: $src_file not found"
        exit 1
    fi

    for dir in "${backup_dirs[@]}"; do
    echo "Processing: $dir"

    # Create directory if it doesn't exist
    mkdir -p "$dir"

    # Verify it exists and is a directory
    if [[ -d "$dir" ]]; then
        cp "$src_file" "$dir/"
        echo "  Copied $src_file → $dir"
    else
        echo "  Failed to create directory: $dir" >&2
    fi
    done

fi