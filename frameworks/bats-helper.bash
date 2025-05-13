#!/usr/bin/env bash
# bats-helper.bash - Unified helper for BATS tests
# A comprehensive helper for BATS tests with plugin loading and utility functions

# Get the directory of this script
FRAMEWORKS_DIR="$(dirname "$BASH_SOURCE")"

# Read environment variables directly to ensure they're not lost in subshells
if [ -n "$TEST_DIR_MODE_ENV" ]; then
  TEST_DIR_MODE="$TEST_DIR_MODE_ENV"
else
  # Check if the variable is set in the environment
  if printenv TEST_DIR_MODE >/dev/null 2>&1; then
    TEST_DIR_MODE="$(printenv TEST_DIR_MODE)"
  else
    TEST_DIR_MODE="temp"
  fi
fi

if [ -n "$TEST_DIR_CLEAN_ENV" ]; then
  TEST_DIR_CLEAN="$TEST_DIR_CLEAN_ENV"
else
  # Check if the variable is set in the environment
  if printenv TEST_DIR_CLEAN >/dev/null 2>&1; then
    TEST_DIR_CLEAN="$(printenv TEST_DIR_CLEAN)"
  else
    TEST_DIR_CLEAN="clean"
  fi
fi

# Export to ensure they're available to subprocesses
export TEST_DIR_MODE TEST_DIR_CLEAN

# Permanent test directory path (used if TEST_DIR_MODE=perm)
PERM_TEST_DIR=${PERM_TEST_DIR:-"/Users/marco/Github/scripts-collection/test_output"}

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

# Create a test directory based on TEST_DIR_MODE
# Usage: create_test_dir [test_name]
# Returns: Sets TEST_DIR to the created directory path
create_test_dir() {
  local test_name="${1:-$(basename "$BATS_TEST_FILENAME" .bats)}"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  
  case "$TEST_DIR_MODE" in
    perm)
      # Create a permanent test directory
      TEST_DIR="$PERM_TEST_DIR/${test_name}_${timestamp}"
      mkdir -p "$TEST_DIR"
      log_test "INFO" "Created permanent test directory: $TEST_DIR"
      ;;
    temp|*)
      # Create a temporary test directory (default)
      TEST_DIR=$(mktemp -d)
      log_test "INFO" "Created temporary test directory: $TEST_DIR"
      ;;
  esac
  
  export TEST_DIR
  return 0
}

# Clean up test directory based on TEST_DIR_CLEAN
# Usage: cleanup_test_dir
cleanup_test_dir() {
  if [ -z "$TEST_DIR" ]; then
    return 0
  fi
  
  case "$TEST_DIR_CLEAN" in
    clean)
      # Remove the test directory
      if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
        log_test "INFO" "Cleaned up test directory: $TEST_DIR"
      fi
      ;;
    noclean)
      # Keep the test directory
      log_test "INFO" "Keeping test directory for inspection: $TEST_DIR"
      ;;
  esac
  
  return 0
}

# Helper function to create a test script
create_test_script() {
  local script_path="$1"
  local script_content="$2"
  
  # Create parent directory if needed
  mkdir -p "$(dirname "$script_path")"
  
  # Write script content
  echo "$script_content" > "$script_path"
  chmod +x "$script_path"
  
  log_test "INFO" "Created test script at: $script_path"
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

# Initialize the test environment
initialize_test_env() {
  # Create permanent test directory if needed
  if [[ "$TEST_DIR_MODE" == "perm" && ! -d "$PERM_TEST_DIR" ]]; then
    mkdir -p "$PERM_TEST_DIR"
    log_test "INFO" "Created permanent test directory root: $PERM_TEST_DIR"
  fi
  
  # Print configuration
  log_test "INFO" "Test directory mode: $TEST_DIR_MODE"
  log_test "INFO" "Test directory cleanup: $TEST_DIR_CLEAN"
  
  if [[ "$TEST_DIR_MODE" == "perm" ]]; then
    log_test "INFO" "Permanent test directory: $PERM_TEST_DIR"
  fi
}

# Print helper information
echo -e "${GREEN}[BATS-HELPER]${NC} Loaded bats-helper.bash from $FRAMEWORKS_DIR"
initialize_test_env
