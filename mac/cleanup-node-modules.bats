#!/usr/bin/env bats
# cleanup-node-modules.bats - Tests for cleanup-node-modules.sh

# Path to the scripts (adjust if needed)
SCRIPT_PATH="/Users/marco/Github/scripts-collection/mac/cleanup-node-modules.sh"
LOGGER_PATH="/Users/marco/Github/scripts-collection/mac/logger.sh"

# Load test helpers if available
FRAMEWORKS_DIR="/Users/marco/Github/scripts-collection/frameworks"
if [ ! -d "$FRAMEWORKS_DIR" ]; then
    mkdir -p "$FRAMEWORKS_DIR"
fi

# Load the unified bats-helper
load_helper() {
    # Check if helper exists
    if [ ! -f "$FRAMEWORKS_DIR/bats-helper.bash" ]; then
        echo "ERROR: bats-helper.bash not found at $FRAMEWORKS_DIR/bats-helper.bash"
        echo "Please create the helper file first."
        exit 1
    fi
    
    # Load the helper
    source "$FRAMEWORKS_DIR/bats-helper.bash"
    
    # Load plugins if available
    load_bats_support || true
    load_bats_assert || true
}

# Load helpers
load_helper

# Setup - runs before each test
setup() {
    # Create test directory based on mode
    create_test_dir "cleanup_node_modules_$(echo "$BATS_TEST_NAME" | tr ' ' '_')"

    # Create a test structure with node_modules directories
    mkdir -p "$TEST_DIR/project1/node_modules"
    mkdir -p "$TEST_DIR/project2/node_modules"
    mkdir -p "$TEST_DIR/project3/subfolder/node_modules"

    # Create some files to give the directories size
    dd if=/dev/zero of="$TEST_DIR/project1/node_modules/file1" bs=1M count=2 2>/dev/null
    dd if=/dev/zero of="$TEST_DIR/project2/node_modules/file2" bs=1M count=3 2>/dev/null
    dd if=/dev/zero of="$TEST_DIR/project3/subfolder/node_modules/file3" bs=512K count=4 2>/dev/null
    
    # Log the test structure
    log_test "INFO" "Created test structure with 3 node_modules directories"
}

# Teardown - runs after each test
teardown() {
    # Clean up test directory based on mode
    cleanup_test_dir
}

# Helper to count node_modules directories
count_node_modules() {
    find "$1" -name node_modules -type d | wc -l | tr -d ' '
}

# Test 1: Core functionality - finding node_modules directories
@test "Script finds all node_modules directories" {
    # Run in dry-run mode
    run bash "$SCRIPT_PATH" "$TEST_DIR" --dry-run

    # Check status and output
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found 3 node_modules directories" ]]
    [[ "$output" =~ "project1/node_modules" ]]
    [[ "$output" =~ "project2/node_modules" ]]
    [[ "$output" =~ "project3/subfolder/node_modules" ]]
}

# Test 2: Dry-run mode doesn't delete anything
@test "Dry-run mode doesn't delete anything" {
    # Count initial directories
    initial_count=$(count_node_modules "$TEST_DIR")
    [ "$initial_count" -eq 3 ]

    # Run in dry-run mode
    run bash "$SCRIPT_PATH" "$TEST_DIR" --dry-run

    # Verify nothing was deleted
    after_count=$(count_node_modules "$TEST_DIR")
    [ "$after_count" -eq 3 ]
}

# Test 3: Directory parameter works correctly
@test "Directory parameter targets specific directory" {
    # Run on just project1
    run bash "$SCRIPT_PATH" "$TEST_DIR/project1" --dry-run

    # Verify it only found one directory
    [ "$status" -eq 0 ]
    [[ "$output" =~ "Found 1 node_modules director" ]]
    [[ "$output" =~ "project1/node_modules" ]]
    [[ ! "$output" =~ "project2/node_modules" ]]
}

# Test 4: Handles directories with no node_modules
@test "Script handles directories with no node_modules" {
    # Create an empty directory
    EMPTY_DIR="$TEST_DIR/empty"
    mkdir -p "$EMPTY_DIR"

    # Run on the empty directory
    run bash "$SCRIPT_PATH" "$EMPTY_DIR"

    # Check output
    [ "$status" -eq 0 ]
    [[ "$output" =~ "No node_modules directories found" ]]
}

# Test 5: Test deletion with 'yes' response using input redirection
@test "Deletion works when confirmed with 'yes'" {
    # Count initial directories
    initial_count=$(count_node_modules "$TEST_DIR")
    [ "$initial_count" -eq 3 ]

    # Run with 'yes' as input
    echo "yes" | run bash "$SCRIPT_PATH" "$TEST_DIR"

    # Verify directories were deleted
    after_count=$(count_node_modules "$TEST_DIR")
    [ "$after_count" -eq 0 ]
}

# Test 6: Test with 'no' response using input redirection
@test "No deletion occurs when responding with 'no'" {
    # Count initial directories
    initial_count=$(count_node_modules "$TEST_DIR")
    [ "$initial_count" -eq 3 ]

    # Run with 'no' as input
    echo "no" | run bash "$SCRIPT_PATH" "$TEST_DIR"

    # Verify nothing was deleted
    after_count=$(count_node_modules "$TEST_DIR")
    [ "$after_count" -eq 3 ]
}

# Test 7: Verbose mode provides more output
@test "Verbose mode shows additional information" {
    # Run with verbose flag
    run bash "$SCRIPT_PATH" "$TEST_DIR" --dry-run --verbose

    # Check for debug messages
    [ "$status" -eq 0 ]
    [[ "$output" =~ "[DEBUG]" ]]
}

# Test 8: Test deeply nested directories
@test "Script finds deeply nested node_modules directories" {
    # Create a deeply nested structure
    NESTED_DIR="$TEST_DIR/deep/nesting/structure/with/node_modules"
    mkdir -p "$NESTED_DIR"
    
    # Run the script
    run bash "$SCRIPT_PATH" "$TEST_DIR" --dry-run
    
    # Check that it found the deeply nested directory
    [ "$status" -eq 0 ]
    [[ "$output" =~ "deep/nesting/structure/with/node_modules" ]]
}

# Test 9: Create a test script to check logger functionality
@test "Logger provides colorized output" {
    # Create a temporary test script
    TEST_SCRIPT="$TEST_DIR/test_logger.sh"
    
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
source "$LOGGER_PATH"

# Enable all log levels
logger_set_verbose true

# Test all log levels
log_error "Test error message"
log_warning "Test warning message"
log_info "Test info message"
log_debug "Test debug message"
log_success "Test success message"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the test script directly (not with 'run' command to preserve colors)
    output=$("$TEST_SCRIPT")
    
    # Check if output contains expected messages
    [ -n "$output" ]
    [[ "$output" =~ "[ERROR]" ]]
    [[ "$output" =~ "[WARNING]" ]]
    [[ "$output" =~ "[INFO]" ]]
    [[ "$output" =~ "[DEBUG]" ]]
    [[ "$output" =~ "[SUCCESS]" ]]
    
    # Print the output to show the colors in the test results
    echo "Logger output sample (should have colors):"
    "$TEST_SCRIPT"
}
