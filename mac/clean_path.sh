
#!/bin/bash

# Define the clean, consolidated PATH
CLEAN_PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/Users/marco/bin:/Users/marco/sbin:/System/Cryptexes/App/usr/bin:/usr/bin:/bin:/usr/sbin:/sbin:/opt/X11/bin:/Library/Apple/usr/bin:/Library/TeX/texbin:/Applications/Little Snitch.app/Contents/Components:/Applications/iTerm.app/Contents/Resources/utilities:/opt/homebrew/opt/fzf/bin"

# Function to clean a file
clean_file() {
    local file="$1"

    if [ -f "$file" ]; then
        # Backup the original file
        cp "$file" "${file}.bak"

        # Remove lines containing export PATH and replace with the clean PATH
        sed -i '' '/export PATH/d' "$file"
        # Insert the clean PATH at the beginning of the file
        sed -i '' "1i\\
export PATH=\"$CLEAN_PATH\"
        " "$file"

        echo "Cleaned $file"
    else
        echo "$file not found, skipping..."
    fi
}

# Clean the main .zshrc and .config/zsh/zshrc
clean_file "$HOME/.zshrc"
clean_file "$HOME/.config/zsh/zshrc"

# Remove redundant or commented-out export PATH lines from other config files
for file in $HOME/.zshrc.omz-backup $HOME/.zshrc.omz-uninstalled-* $HOME/.zshrc.orig $HOME/.config/zsh/completions.zsh $HOME/.config/zsh/zshenv; do
    if [ -f "$file" ]; then
        # Backup the original file
        cp "$file" "${file}.bak"

        # Comment out any existing export PATH lines
        sed -i '' 's/^export PATH/# export PATH/' "$file"

        echo "Commented out PATH in $file"
    fi
done

# Reload .zshrc to apply changes
source "$HOME/.zshrc"

# Show the resulting PATH
echo "Cleaned PATH is: $PATH"

