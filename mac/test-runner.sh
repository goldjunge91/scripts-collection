#!/bin/bash
# test-runner.sh - A comprehensive test runner for the node_modules cleanup script
# This combines the best features of run-tests.sh and setup-tests.sh

# Get the directory of this script (more robust than hardcoded paths)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Define frameworks directory
FRAMEWORKS_DIR="/Users/marco/Github.tmp/scripts-collection/frameworks"
mkdir -p "$FRAMEWORKS_DIR"

echo "Setting up test environment..."

# Check if BATS is installed
if ! command -v bats &> /dev/null; then
    echo "BATS not installed. Installing BATS..."
    
    # Check for Homebrew first (macOS-friendly approach)
    if command -v brew &> /dev/null; then
        echo "Using Homebrew to install BATS core..."
        brew install bats-core
    else
        echo "Homebrew not found. Installing BATS manually..."
        TEMP_DIR=$(mktemp -d)
        cd "$TEMP_DIR" || exit 1
        
        # Clone BATS core repository
        git clone https://github.com/bats-core/bats-core.git
        
        # Install BATS
        cd bats-core || exit 1
        sudo ./install.sh /usr/local
        
        cd "$SCRIPT_DIR" || exit 1
    fi
    
    echo "BATS core installed successfully!"
fi

# Check if BATS plugins are installed in the frameworks directory
if [ ! -d "$FRAMEWORKS_DIR/bats-support" ] || [ ! -d "$FRAMEWORKS_DIR/bats-assert" ]; then
    echo "Installing BATS plugins to $FRAMEWORKS_DIR..."
    
    # Create a temporary directory
    TEMP_DIR=$(mktemp -d)
    CURRENT_DIR=$(pwd)
    
    # Clone BATS plugin repositories
    (
        cd "$TEMP_DIR" || exit 1
        git clone https://github.com/bats-core/bats-support.git
        git clone https://github.com/bats-core/bats-assert.git
    )
    
    # Copy to frameworks directory
    mkdir -p "$FRAMEWORKS_DIR"
    cp -R "$TEMP_DIR/bats-support" "$FRAMEWORKS_DIR/"
    cp -R "$TEMP_DIR/bats-assert" "$FRAMEWORKS_DIR/"
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    # Make sure we're back in the original directory
    cd "$CURRENT_DIR" || exit 1
    
    echo "BATS plugins installed to $FRAMEWORKS_DIR!"
fi

# Check for the unified BATS helper
HELPER_FILE="$FRAMEWORKS_DIR/bats-helper.bash"
if [ ! -f "$HELPER_FILE" ]; then
    echo "BATS helper not found at $HELPER_FILE. Creating..."
    
    # Create the helper file
    cat > "$HELPER_FILE" << 'EOF'
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
      echo -e "${GREEN}[TEST-INFO]${NC} Created permanent test directory: $TEST_DIR"
      ;;
    temp|*)
      # Create a temporary test directory (default)
      TEST_DIR=$(mktemp -d)
      echo -e "${GREEN}[TEST-INFO]${NC} Created temporary test directory: $TEST_DIR"
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
        echo -e "${GREEN}[TEST-INFO]${NC} Cleaned up test directory: $TEST_DIR"
      fi
      ;;
    noclean)
      # Keep the test directory
      echo -e "${GREEN}[TEST-INFO]${NC} Keeping test directory for inspection: $TEST_DIR"
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
  
  echo -e "${GREEN}[TEST-INFO]${NC} Created test script at: $script_path"
}

# Helper function to extract log file path from output
extract_log_file_path() {
  local output="$1"
  echo "$output" | grep -o "LOG_FILE:.*" | cut -d':' -f2
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
    echo -e "${GREEN}[TEST-INFO]${NC} Created permanent test directory root: $PERM_TEST_DIR"
  fi
  
  # Print configuration
  echo -e "${GREEN}[TEST-INFO]${NC} Test directory mode: $TEST_DIR_MODE"
  echo -e "${GREEN}[TEST-INFO]${NC} Test directory cleanup: $TEST_DIR_CLEAN"
  
  if [[ "$TEST_DIR_MODE" == "perm" ]]; then
    echo -e "${GREEN}[TEST-INFO]${NC} Permanent test directory: $PERM_TEST_DIR"
  fi
}

# Print helper information
echo -e "${GREEN}[BATS-HELPER]${NC} Loaded bats-helper.bash from $FRAMEWORKS_DIR"
initialize_test_env
EOF
    
    chmod +x "$HELPER_FILE"
    echo "Created unified BATS helper at $HELPER_FILE"
else
    echo "Using existing BATS helper at $HELPER_FILE"
fi

# Make sure all required scripts are executable
chmod +x "$SCRIPT_DIR/cleanup-node-modules.sh"
chmod +x "$SCRIPT_DIR/logger.sh"
chmod +x "$SCRIPT_DIR/tests-bats.sh"

# Verify logger.sh is properly set up
if [ ! -f "$SCRIPT_DIR/logger.sh" ]; then
    echo "ERROR: logger.sh not found at $SCRIPT_DIR/logger.sh"
    exit 1
fi

# Test the logger directly
echo "Testing logger directly (should show colored output):"
(
    source "$SCRIPT_DIR/logger.sh"
    logger_set_verbose true
    log_error "Test error message"
    log_warning "Test warning message"
    log_info "Test info message"
    log_debug "Test debug message"
    log_success "Test success message"
)
echo ""

# Parse any test configuration options passed to test-runner.sh
parse_test_options() {
    for arg in "$@"; do
        case $arg in
            --perm)
                export TEST_DIR_MODE_ENV="perm"
                ;;
            --temp)
                export TEST_DIR_MODE_ENV="temp"
                ;;
            --clean)
                export TEST_DIR_CLEAN_ENV="clean"
                ;;
            --noclean)
                export TEST_DIR_CLEAN_ENV="noclean"
                ;;
        esac
    done
    
    # Print test configuration
    echo "Test configuration:"
    echo "- Directory mode: ${TEST_DIR_MODE_ENV:-temp}"
    echo "- Cleanup mode: ${TEST_DIR_CLEAN_ENV:-clean}"
}

# Parse test options
parse_test_options "$@"

echo "Running tests..."
# Use BATS_COLOR=true to encourage color output
# Pass environment variables to bats
TEST_DIR_MODE_ENV="${TEST_DIR_MODE_ENV:-temp}" TEST_DIR_CLEAN_ENV="${TEST_DIR_CLEAN_ENV:-clean}" BATS_COLOR=true bats "$SCRIPT_DIR/tests-bats.sh"

echo "Tests completed!"
