#!/bin/bash

# Create a temporary file to store the output
temp_file=$(mktemp)

# Loop through all installed packages
dpkg-query -W -f='${Package}\n' | while read package; do
    # Get apt-cache policy output for the package
    apt-cache policy "$package" > "$temp_file"

    # Extract installed and candidate versions using awk
    installed_version=$(awk '/Installed:/{print $2}' "$temp_file")
    candidate_version=$(awk '/Candidate:/{print $2}' "$temp_file")

    # Compare versions and print output
    if [[ -n "$installed_version" && -n "$candidate_version" ]]; then # Check if both versions are found
        if [[ "$installed_version" == "(none)" ]]; then
            echo "$package: Not installed, Candidate: $candidate_version"
        elif [[ "$installed_version" != "$candidate_version" ]]; then
            echo "$package: Installed: $installed_version, Candidate: $candidate_version"
        else
             echo "$package: Installed: $installed_version, Up-to-date"
        fi
    else
        echo "$package: Could not retrieve version information"
    fi
done

# Remove the temporary file
rm "$temp_file"
