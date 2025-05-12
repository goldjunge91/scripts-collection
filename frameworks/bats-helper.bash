#!/usr/bin/env bash
# bats-helper.bash - Unified helper for BATS tests
# A comprehensive helper for BATS tests with plugin loading and utility functions

# Get the directory of this script
FRAMEWORKS_DIR="$(dirname "$BASH_SOURCE")"

# Enable colored output in BATS
export BATS_COLOR=true
export BATS_TERMINAL_WIDTH=120

# Define colors for better test output
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[0;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export MAGENTA='\033[0;35m'
export NC='\033[0m' # No Color

# Plugin paths
BATS_SUPPORT_DIR="${FRAMEWORKS_DIR}/bats-support"
BATS_ASSERT_DIR="${FRAMEWORKS_DIR}/bats-assert"

# Load the bats-support plugin
load_bats_support() {
  if [ -f "${BATS_SUPPORT_DIR}/load.bash" ]; then
    load "${BATS_SUPPORT_DIR}/load.bash"
  else
    echo "${YELLOW}WARNING:${NC} bats-support not found at ${BATS_SUPPORT_DIR}"
    return 1
  fi
}

# Load the bats-assert plugin
load_bats_assert() {
  if [ -f "${BATS_ASSERT_DIR}/load.bash" ]; then
    load "${BATS_ASSERT_DIR}/load.bash"
  else
    echo "${YELLOW}WARNING:${NC} bats-assert not found at ${BATS_ASSERT_DIR}"
    return 1
  fi
}

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

# Helper function to create a temporary test script
create_test_script() {
  local script_path="$1"
  local script_content="$2"
  
  echo "$script_content" > "$script_path"
  chmod +x "$script_path"
  
  echo "Created test script at: $script_path"
}

# Helper function to extract log file path from output
extract_log_file_path() {
  local output="$1"
  echo "$output" | grep -o "LOG_FILE:.*" | cut -d':' -f2
}

# Print diagnostic info about the test environment
print_test_info() {
  echo "BATS version: $(bats --version)"
  echo "Test directory: $BATS_TEST_DIRNAME"
  echo "FRAMEWORKS_DIR: $FRAMEWORKS_DIR"
  echo "BATS_SUPPORT_DIR: $BATS_SUPPORT_DIR"
  echo "BATS_ASSERT_DIR: $BATS_ASSERT_DIR"
}

# Log a message to the test output
log_test() {
  local level="$1"
  local message="$2"
  local color=""
  
  case "$level" in
    "INFO")    color="$GREEN" ;;
    "WARNING") color="$YELLOW" ;;
    "ERROR")   color="$RED" ;;
    "DEBUG")   color="$BLUE" ;;
    *)         color="$NC" ;;
  esac
  
  echo -e "${color}[TEST-$level]${NC} $message"
}

echo -e "${GREEN}[BATS-HELPER]${NC} Loaded bats-helper.bash from $FRAMEWORKS_DIR"
