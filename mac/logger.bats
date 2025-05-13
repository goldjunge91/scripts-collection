#!/usr/bin/env bats
# logger.bats - Tests for enhanced logger.sh

# Path to the logger script
LOGGER_PATH="/Users/marco/Github/scripts-collection/mac/logger.sh"
MAC_DIR="/Users/marco/Github/scripts-collection/mac"

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
}

# Load helpers
load_helper

# Setup - runs before each test
setup() {
    # Create test directory based on mode
    create_test_dir "logger_$(echo "$BATS_TEST_NAME" | tr ' ' '_')"
    
    # Create a test script that uses the logger
    TEST_SCRIPT="$TEST_DIR/test_script.sh"
    
    # Log test setup
    log_test "INFO" "Setting up logger test in $TEST_DIR"
}

# Teardown - runs after each test
teardown() {
    # Clean up test directory based on mode
    cleanup_test_dir
    
    # Clean up any log files created in the mac directory
    # Only if we're in clean mode
    if [[ "$TEST_DIR_CLEAN" == "clean" ]]; then
        rm -f "$MAC_DIR/test_script.log"
        rm -f "$MAC_DIR/specific_name_script.log"
        rm -f "$MAC_DIR/script.log"
        rm -f "$MAC_DIR/bats.log"
        log_test "INFO" "Cleaned up log files in $MAC_DIR"
    fi
}

# Test 1: Basic logging functionality and file creation
@test "Logger creates log file and logs all message types" {
    # Create a test script
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
# Force script name for better testing
export CALLER_SCRIPT="test_script.sh"
export CALLER_PATH="$TEST_DIR"

source "$LOGGER_PATH"

# Test all log types
log_error "ERROR_MESSAGE"
log_warning "WARNING_MESSAGE"
log_info "INFO_MESSAGE"
log_debug "DEBUG_MESSAGE"
log_success "SUCCESS_MESSAGE"

# Print the log file path so we can check it
echo "LOG_FILE:\$LOG_FILE"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the script
    run "$TEST_SCRIPT"
    
    # Debug output
    echo "Script output: $output"
    
    # Get the log file path from the output
    LOG_FILE_PATH=$(echo "$output" | grep -o "LOG_FILE:.*" | cut -d':' -f2)
    echo "Log file path: $LOG_FILE_PATH"
    
    # Check output
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ERROR_MESSAGE" ]]
    [[ "$output" =~ "WARNING_MESSAGE" ]]
    [[ "$output" =~ "INFO_MESSAGE" ]]
    [[ ! "$output" =~ "DEBUG_MESSAGE" ]] # Debug shouldn't show by default
    [[ "$output" =~ "SUCCESS_MESSAGE" ]]
    
    # Check that log file exists
    [ -f "$LOG_FILE_PATH" ]
    
    # Check log file contains all messages
    log_content=$(cat "$LOG_FILE_PATH")
    echo "Log content: $log_content"
    
    [[ "$log_content" =~ "ERROR_MESSAGE" ]]
    [[ "$log_content" =~ "WARNING_MESSAGE" ]]
    [[ "$log_content" =~ "INFO_MESSAGE" ]]
    [[ "$log_content" =~ "DEBUG_MESSAGE" ]] # Debug should appear in log file
    [[ "$log_content" =~ "SUCCESS_MESSAGE" ]]
    [[ "$log_content" =~ "test_script" ]] # Should contain script name
}

# Test 2: Logger captures important message types
@test "Logger captures all message types correctly" {
    # Create a test script that tests different log levels
    TEST_LOG="$TEST_DIR/all_log_types.log"
    
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
# Custom log file location to avoid path issues
export LOG_FILE="$TEST_LOG"

source "$LOGGER_PATH"

# Test all log types
log_error "ERROR_TEST_MESSAGE"
log_warning "WARNING_TEST_MESSAGE"
log_info "INFO_TEST_MESSAGE"
log_debug "DEBUG_TEST_MESSAGE"
log_success "SUCCESS_TEST_MESSAGE"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the script
    run "$TEST_SCRIPT"
    
    # Check that the log file exists
    [ -f "$TEST_LOG" ]
    
    # Read log contents
    log_content=$(cat "$TEST_LOG")
    echo "Log content: $log_content"
    
    # Verify all message types are in the log
    [[ "$log_content" =~ "ERROR_TEST_MESSAGE" ]]
    [[ "$log_content" =~ "WARNING_TEST_MESSAGE" ]]
    [[ "$log_content" =~ "INFO_TEST_MESSAGE" ]]
    [[ "$log_content" =~ "DEBUG_TEST_MESSAGE" ]]
    [[ "$log_content" =~ "SUCCESS_TEST_MESSAGE" ]]
}

# Test 3: Logger creates header with metadata
@test "Logger creates proper log file header" {
    # Create a custom log file location
    TEST_LOG="$TEST_DIR/header_test.log"
    
    # Create a test script
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
# Custom log file location to avoid path issues
export LOG_FILE="$TEST_LOG"

source "$LOGGER_PATH"
log_info "This is a test message"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the script
    run "$TEST_SCRIPT"
    
    # Check that log file exists
    [ -f "$TEST_LOG" ]
    
    # Check log content for header elements
    log_content=$(cat "$TEST_LOG")
    echo "Log content: $log_content"
    
    # Check for key header elements
    [[ "$log_content" =~ "===== Log started at" ]]
    [[ "$log_content" =~ "Script:" ]]
    [[ "$log_content" =~ "Path:" ]]
    [[ "$log_content" =~ "========" ]]
}

# Test 4: Custom log file location
@test "Logger can use custom log file location" {
    # Create a test script
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
source "$LOGGER_PATH"

# Set custom log file
CUSTOM_LOG="$TEST_DIR/custom_log_location.log"
logger_set_log_file "\$CUSTOM_LOG"

log_info "This should go to the custom log file"
echo "CUSTOM_LOG:\$LOG_FILE"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the script
    run "$TEST_SCRIPT"
    
    # Debug output
    echo "Script output: $output"
    
    # Get the custom log path
    CUSTOM_LOG="$TEST_DIR/custom_log_location.log"
    
    # Check custom log file exists
    [ -f "$CUSTOM_LOG" ]
    
    # Check it contains the message
    log_content=$(cat "$CUSTOM_LOG")
    [[ "$log_content" =~ "This should go to the custom log file" ]]
}

# Test 5: Logger preserves message order in log file
@test "Logger preserves message order in log file" {
    # Create a test script
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
# Define original command to ensure proper script name detection
export ORIGINAL_COMMAND="$TEST_SCRIPT"

# Force script name for better testing
export CALLER_SCRIPT="test_script.sh"
export CALLER_PATH="$TEST_DIR"

source "$LOGGER_PATH"

# Log messages in specific order
log_info "FIRST MESSAGE"
log_debug "SECOND MESSAGE"
log_warning "THIRD MESSAGE"
log_error "FOURTH MESSAGE"
log_success "FIFTH MESSAGE"

echo "LOG_FILE:\$LOG_FILE"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the script
    run "$TEST_SCRIPT"
    
    # Debug output
    echo "Script output: $output"
    
    # Get the log file path from the output
    LOG_FILE_PATH=$(echo "$output" | grep -o "LOG_FILE:.*" | cut -d':' -f2)
    echo "Log file path: $LOG_FILE_PATH"
    
    # Check file exists
    [ -f "$LOG_FILE_PATH" ]
    
    # Read log file content
    log_content=$(cat "$LOG_FILE_PATH")
    echo "Log content: $log_content"
    
    # Check message order using positional comparison
    first_pos=$(echo "$log_content" | grep -n "FIRST MESSAGE" | cut -d':' -f1)
    second_pos=$(echo "$log_content" | grep -n "SECOND MESSAGE" | cut -d':' -f1)
    third_pos=$(echo "$log_content" | grep -n "THIRD MESSAGE" | cut -d':' -f1)
    fourth_pos=$(echo "$log_content" | grep -n "FOURTH MESSAGE" | cut -d':' -f1)
    fifth_pos=$(echo "$log_content" | grep -n "FIFTH MESSAGE" | cut -d':' -f1)
    
    # Verify order is preserved
    [ "$first_pos" -lt "$second_pos" ]
    [ "$second_pos" -lt "$third_pos" ]
    [ "$third_pos" -lt "$fourth_pos" ]
    [ "$fourth_pos" -lt "$fifth_pos" ]
}

# Test 6: Logger initialization options
@test "Logger accepts initialization options" {
    # Create a test script with explicit init options
    CUSTOM_LOG="$TEST_DIR/explicit_custom.log"
    
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
# Define original command to ensure proper script name detection
export ORIGINAL_COMMAND="$TEST_SCRIPT"

# Custom file for logging
source "$LOGGER_PATH" --verbose --log-file=$CUSTOM_LOG

# This debug message should show due to verbose mode
log_debug "This debug message should appear due to verbose mode"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the script
    run "$TEST_SCRIPT"
    
    # Debug output
    echo "Script output: $output"
    
    # Check output shows debug message
    [ "$status" -eq 0 ]
    [[ "$output" =~ "This debug message should appear due to verbose mode" ]]
    
    # Check custom log file was created
    [ -f "$CUSTOM_LOG" ]
    
    # Check log content
    log_content=$(cat "$CUSTOM_LOG")
    echo "Log content: $log_content"
    
    # Verify log contains the debug message
    [[ "$log_content" =~ "This debug message should appear due to verbose mode" ]]
}
