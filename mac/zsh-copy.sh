#!/bin/sh

# Define source and destination directories
source_dir="/etc/zsh"
user_source_dir="/Users/marco"
dest_dir="/Users/marco/.config/zsh"

# Create destination directory if it doesn't exist
mkdir -p "$dest_dir"

# List of files to copy
system_files="zprofile zshenv zshrc"
user_files=".zprofile .zshenv .zshrc"

# Copy system-wide Zsh files
for file in $system_files; do
    source_file="$source_dir/$file"
    dest_file="$dest_dir/$file"
    
    if [ -f "$source_file" ]; then
        cp "$source_file" "$dest_file"
        echo "Copied $file from $source_dir to $dest_dir"
    else
        echo "Warning: $file not found in $source_dir"
    fi
done

# Copy user-specific Zsh files
for file in $user_files; do
    source_file="$user_source_dir/$file"
    dest_file="$dest_dir/$file"
    
    if [ -f "$source_file" ]; then
        cp "$source_file" "$dest_file"
        echo "Copied $file from $user_source_dir to $dest_dir"
    else
        echo "Warning: $file not found in $user_source_dir"
    fi
done

echo "Zsh configuration files copied to $dest_dir"