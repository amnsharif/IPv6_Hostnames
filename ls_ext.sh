#!/bin/bash

# Check if a directory is provided as an argument
if [ -z "$1" ]; then
  echo "Usage: $0 <directory>"
  exit 1
fi

# Assign the directory to a variable
DIR="$1"

# Check if the provided argument is a valid directory
if [ ! -d "$DIR" ]; then
  echo "Error: $DIR is not a valid directory."
  exit 1
fi

# Find all files in the directory and its subdirectories, extract their extensions, and sort them uniquely
find "$DIR" -type f | sed -E -n 's/.*\.([^./]+)$/\1/p' | sort | uniq

# Explanation:
# 1. find "$DIR" -type f: Finds all files in the directory and its subdirectories.
# 2. sed -E -n 's/.*\.([^./]+)$/\1/p': Extracts the file extension using a regular expression.
#    - The `-n` flag suppresses automatic printing.
#    - The `p` at the end prints only lines where a match is found (files with extensions).
# 3. sort | uniq: Sorts the extensions and removes duplicates.
