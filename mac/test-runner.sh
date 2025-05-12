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

# Create a helper file to load the plugins
HELPER_FILE="$FRAMEWORKS_DIR/bats_load_helper.bash"
if [ -f "$HELPER_FILE" ]; then
    rm "$HELPER_FILE"
fi

cat > "$HELPER_FILE" << 'EOF'
#!/usr/bin/env bash
# Helper script for loading BATS plugins

# Get the directory of this script
FRAMEWORKS_DIR="$(dirname "$BASH_SOURCE")"

# Fixed paths to the plugins
BATS_SUPPORT_DIR="${FRAMEWORKS_DIR}/bats-support"
BATS_ASSERT_DIR="${FRAMEWORKS_DIR}/bats-assert"

load_bats_support() {
  if [ -f "${BATS_SUPPORT_DIR}/load.bash" ]; then
    load "${BATS_SUPPORT_DIR}/load.bash"
  else
    echo "WARNING: bats-support not found at ${BATS_SUPPORT_DIR}"
    return 1
  fi
}

load_bats_assert() {
  if [ -f "${BATS_ASSERT_DIR}/load.bash" ]; then
    load "${BATS_ASSERT_DIR}/load.bash"
  else
    echo "WARNING: bats-assert not found at ${BATS_ASSERT_DIR}"
    return 1
  fi
}
EOF

chmod +x "$HELPER_FILE"
echo "Created BATS helper file at $HELPER_FILE"

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

echo "Running tests..."
# Use BATS_COLOR=true to encourage color output
BATS_COLOR=true bats "$SCRIPT_DIR/tests-bats.sh"

echo "Tests completed!"
