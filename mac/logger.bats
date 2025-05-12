#!/usr/bin/env bats
# logger.bats - Tests for logger.sh

# Path to the logger script
LOGGER_PATH="/Users/marco/Github/scripts-collection/mac/logger.sh"

# Setup - runs before each test
setup() {
    # Create a temporary directory
    TEST_DIR=$(mktemp -d)
    export TEST_DIR
    
    # Path to test script
    TEST_SCRIPT="$TEST_DIR/logger_test.sh"
}

# Teardown - runs after each test
teardown() {
    # Clean up
    if [ -d "$TEST_DIR" ]; then
        rm -rf "$TEST_DIR"
    fi
}

# Test 1: Verify all log levels
@test "Logger shows all message types correctly" {
    # Create a test script
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
source "$LOGGER_PATH"

# Set verbose mode
logger_set_verbose true

# Test all log types
log_error "ERROR_MESSAGE"
log_warning "WARNING_MESSAGE"
log_info "INFO_MESSAGE"
log_debug "DEBUG_MESSAGE"
log_success "SUCCESS_MESSAGE"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the script
    run "$TEST_SCRIPT"
    
    # Check output contains all messages
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ERROR_MESSAGE" ]]
    [[ "$output" =~ "WARNING_MESSAGE" ]]
    [[ "$output" =~ "INFO_MESSAGE" ]]
    [[ "$output" =~ "DEBUG_MESSAGE" ]]
    [[ "$output" =~ "SUCCESS_MESSAGE" ]]
}

# Test 2: Test verbose mode control
@test "Logger respects verbose mode setting" {
    # Create a test script
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
source "$LOGGER_PATH"

# Test with verbose off (default)
log_debug "THIS_SHOULD_NOT_APPEAR"

# Enable verbose mode
logger_set_verbose true

# Now debug should show
log_debug "THIS_SHOULD_APPEAR"

# Disable verbose again
logger_set_verbose false

# This should be hidden again
log_debug "THIS_SHOULD_NOT_APPEAR_2"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the script
    run "$TEST_SCRIPT"
    
    # Check what appears and doesn't appear
    [ "$status" -eq 0 ]
    [[ ! "$output" =~ "THIS_SHOULD_NOT_APPEAR" ]]
    [[ "$output" =~ "THIS_SHOULD_APPEAR" ]]
    [[ ! "$output" =~ "THIS_SHOULD_NOT_APPEAR_2" ]]
}

# Test 3: Test log level control
@test "Logger respects log level settings" {
    # Create a test script
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
source "$LOGGER_PATH"

# Set to error only (level 0)
logger_set_level 0

# These should not appear
log_warning "WARNING_HIDDEN"
log_info "INFO_HIDDEN"
log_debug "DEBUG_HIDDEN"

# This should appear
log_error "ERROR_VISIBLE"

# Set to warning level (1)
logger_set_level 1

# This should now appear
log_warning "WARNING_VISIBLE"

# These should still be hidden
log_info "INFO_STILL_HIDDEN"
log_debug "DEBUG_STILL_HIDDEN"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the script
    run "$TEST_SCRIPT"
    
    # Check what appears and doesn't appear
    [ "$status" -eq 0 ]
    [[ "$output" =~ "ERROR_VISIBLE" ]]
    [[ "$output" =~ "WARNING_VISIBLE" ]]
    [[ ! "$output" =~ "WARNING_HIDDEN" ]]
    [[ ! "$output" =~ "INFO_HIDDEN" ]]
    [[ ! "$output" =~ "DEBUG_HIDDEN" ]]
    [[ ! "$output" =~ "INFO_STILL_HIDDEN" ]]
    [[ ! "$output" =~ "DEBUG_STILL_HIDDEN" ]]
}

# Test 4: Test user input via log_question
@test "Logger can prompt for and capture user input" {
    # Create a test script
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
source "$LOGGER_PATH"

# Ask a question and use echo to capture the answer
log_question "What is your name?" "DefaultName"
echo "CAPTURED_ANSWER: \$ANSWER"

# Test with no default value
echo "TestInput" | log_question "Enter something:"
echo "CAPTURED_INPUT: \$ANSWER"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run with default value (no input provided)
    run bash -c "$TEST_SCRIPT < /dev/null"
    
    # Check default value was used
    [ "$status" -eq 0 ]
    [[ "$output" =~ "CAPTURED_ANSWER: DefaultName" ]]
    
    # Run again with input provided for the second question
    echo "UserInput" > "$TEST_DIR/input.txt"
    run bash -c "$TEST_SCRIPT < $TEST_DIR/input.txt"
    
    # Check input was captured
    [[ "$output" =~ "CAPTURED_INPUT: UserInput" ]]
}

# Test 5: Test logger initialization
@test "Logger initializes with correct options" {
    # Create a test script
    cat > "$TEST_SCRIPT" << EOF
#!/bin/bash
source "$LOGGER_PATH"

# Initialize with verbose flag
logger_init --verbose

# Debug messages should now show (only if verbose)
log_debug "DEBUG_SHOULD_SHOW"

# Reset to normal mode
logger_set_verbose false

# This should not show
log_debug "DEBUG_SHOULD_NOT_SHOW"
EOF
    
    chmod +x "$TEST_SCRIPT"
    
    # Run the script
    run "$TEST_SCRIPT"
    
    # Check output
    [ "$status" -eq 0 ]
    [[ "$output" =~ "DEBUG_SHOULD_SHOW" ]]
    [[ ! "$output" =~ "DEBUG_SHOULD_NOT_SHOW" ]]
}
