#!/bin/bash

# Input directory containing the M3U playlist and FLAC files
INPUT_DIR="/home/amin/Music"

# Input M3U playlist (relative to INPUT_DIR)
M3U_PLAYLIST="favorites.m3u"

# Output directory for MP3 files
OUTPUT_DIR="converted_mp3"

# Number of parallel jobs (default to number of threads)
JOBS=$(nproc)

# Create the output directory if it doesn't exist
mkdir -p "$OUTPUT_DIR"

# Temporary file to store the list of FLAC files
TEMP_FILELIST=$(mktemp)

# Extract valid file paths from the M3U playlist and decode URL-encoded characters
grep -v '^#' "$INPUT_DIR/$M3U_PLAYLIST" | grep -v '^$' | while IFS= read -r file; do
    decoded_file=$(echo -e "$file" | sed 's/%20/ /g; s/%21/!/g; s/%22/"/g; s/%23/#/g; s/%24/$/g; s/%25/%/g; s/%26/&/g; s/%27/'\''/g; s/%28/(/g; s/%29/)/g; s/%2A/*/g; s/%2B/+/g; s/%2C/,/g; s/%2D/-/g; s/%2E/./g; s/%2F/\//g')
    echo "$decoded_file"
done > "$TEMP_FILELIST"

# Function to convert a single FLAC file to MP3
convert_to_mp3() {
    local file="$1"
    local output_file="$OUTPUT_DIR/$(basename "$file" .flac).mp3"
    ffmpeg -i "$file" -codec:a libmp3lame -qscale:a 2 "$output_file"
    echo "Converted: $file -> $output_file"
}

# Export the function so it can be used by parallel
export -f convert_to_mp3
export OUTPUT_DIR

# Use parallel to process the files
cat "$TEMP_FILELIST" | parallel -j "$JOBS" convert_to_mp3 "$INPUT_DIR/{}"

# Clean up
rm "$TEMP_FILELIST"

echo "Conversion complete! MP3 files are saved in the '$OUTPUT_DIR' directory."
