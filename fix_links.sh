#!/bin/bash

# Directory to search for replacements (modify as needed)
SEARCH_DIRS="/ /usr"

# Find broken symlinks
find /etc/alternatives -xtype l | while read -r link; do
    target=$(readlink "$link")
    filename=$(basename "$target")
    echo "Attempting to fix: $link -> $target"

    # Search for the filename in specified directories
    #new_target=$(find $SEARCH_DIRS -name "$filename" -type f -print -quit 2>/dev/null)
new_target=$(locate -b "$filename" | head -n 1)
    if [ -n "$new_target" ]; then
        # Check if the new target is the same as the symlink's location
        if [ "$(realpath "$new_target")" != "$(realpath "$link")" ]; then
            echo "Found replacement: $new_target"
            ln -sf "$new_target" "$link"
        else
            echo "Skipping: New target would create a loop for $link"
        fi
    else
        echo "No replacement found for $filename"
    fi
done
