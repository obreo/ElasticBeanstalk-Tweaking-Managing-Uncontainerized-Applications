#!/bin/bash

# Size of the swap file in megabytes
SWAP_SIZE_MB=1024

# Directory path for the swap file
SWAP_DIR="/var"

# File path for the swap file
SWAP_FILE_PATH="$SWAP_DIR/swapfile"

# Check if the swap file already exists
if [ -f "$SWAP_FILE_PATH" ]; then
    echo "Swap file already exists. Skipping creation."
else
    # Create the directory if it doesn't exist
    [ -d "$SWAP_DIR" ] || sudo mkdir -p "$SWAP_DIR"

    # Allocate space for the swap file
    fallocate -l "${SWAP_SIZE_MB}M" "$SWAP_FILE_PATH"

    # Set permissions on the swap file
    chmod 600 "$SWAP_FILE_PATH"

    # Make it a swap file
    mkswap "$SWAP_FILE_PATH"

    # Enable the swap file
    swapon "$SWAP_FILE_PATH"

    # Add an entry to /etc/fstab to make the swap file persistent across reboots
    echo "$SWAP_FILE_PATH swap swap defaults 0 0" >> /etc/fstab

    echo "Swap file created and enabled."
fi
