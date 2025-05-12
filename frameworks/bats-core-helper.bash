#!/usr/bin/env bash
# Helper script for BATS tests

# Enable colored output
export BATS_COLOR=true
export BATS_TERMINAL_WIDTH=120

# Define colors for better test output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m' # No Color

# Function to check for ANSI color codes
has_color_code() {
    local str="$1"
    local color_pattern='\x1b\[[0-9;]*m'
    
    if [[ "$str" =~ $color_pattern ]]; then
        return 0  # Contains color code
    else
        return 1  # Does not contain color code
    fi
}
