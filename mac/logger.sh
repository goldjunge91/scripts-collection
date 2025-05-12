#!/bin/bash
# logger.sh - A modular logger for shell scripts with file logging
# Usage: source this file in your scripts and use the logging functions

# Default log level (0=error, 1=warning, 2=info, 3=debug)
LOG_LEVEL=2
VERBOSE=false

# Colors
RED='\033[0;31m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Get script call command for debugging
ORIGINAL_COMMAND=$0
SCRIPT_ARGS=$@

# Get the name and path of the calling script
_get_caller_info() {
    local debug_caller=false
    
    # If set to true, prints debug info about caller detection
    if [[ "$debug_caller" = true ]]; then
        echo "=== Caller detection debug info ==="
        echo "BASH_SOURCE=${BASH_SOURCE[*]}"
        echo "ORIGINAL_COMMAND=$ORIGINAL_COMMAND"
        echo "SCRIPT_ARGS=$SCRIPT_ARGS"
        echo "\$0=$0"
        echo "pwd=$(pwd)"
        echo "=================================="
    fi
    
    # Initialize defaults
    CALLER_SCRIPT="$(basename "$ORIGINAL_COMMAND")"
    CALLER_PATH="$(dirname "$(readlink -f "$ORIGINAL_COMMAND")")"
    
    # Try to find the right source
    # If it's being sourced by another script
    if [[ "${#BASH_SOURCE[@]}" -gt 1 && "${BASH_SOURCE[1]}" != "$0" ]]; then
        CALLER_SCRIPT="$(basename "${BASH_SOURCE[1]}")"
        CALLER_PATH="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    # If it's being executed directly
    elif [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
        CALLER_SCRIPT="$(basename "$0")"
        CALLER_PATH="$(cd "$(dirname "$0")" && pwd)"
    fi
    
    # Ensure we have a proper script name (not bash or logger.sh)
    if [[ "$CALLER_SCRIPT" == "bash" || "$CALLER_SCRIPT" == "sh" || "$CALLER_SCRIPT" == "logger.sh" ]]; then
        # Extract it from the temp script name in BATS tests
        if [[ "$0" =~ /tmp[^/]+/[^/]+$ ]]; then
            CALLER_SCRIPT="$(basename "$0")"
            CALLER_PATH="$(dirname "$(readlink -f "$0")")"
        else
            # Fallback to a generic name
            CALLER_SCRIPT="script-$$"  # Using PID for uniqueness
            CALLER_PATH="$(pwd)"
        fi
    fi
    
    # Debug info
    if [[ "$debug_caller" = true ]]; then
        echo "Final CALLER_SCRIPT=$CALLER_SCRIPT"
        echo "Final CALLER_PATH=$CALLER_PATH"
    fi
    
    # Export these values so they're available to logging functions
    export CALLER_SCRIPT CALLER_PATH
}

# Initialize the log file
_init_log_file() {
    # Get calling script info if not already set
    if [[ -z "$CALLER_SCRIPT" ]]; then
        _get_caller_info
    fi
    
    # Default log file is in the same directory as the calling script
    if [[ -z "$LOG_FILE" ]]; then
        local script_name
        script_name="$(basename "${CALLER_SCRIPT%.*}")"
        LOG_FILE="${CALLER_PATH}/${script_name}.log"
    fi
    
    # Create log directory if it doesn't exist
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Create or truncate the log file with a header
    echo "===== Log started at $(date) =====" > "$LOG_FILE"
    echo "Script: $CALLER_SCRIPT" >> "$LOG_FILE"
    echo "Path: $CALLER_PATH" >> "$LOG_FILE"
    echo "Command: $ORIGINAL_COMMAND $SCRIPT_ARGS" >> "$LOG_FILE"
    echo "===============================" >> "$LOG_FILE"
    
    # Export the log file path
    export LOG_FILE
}

# Parse arguments
_parse_args() {
    for arg in "$@"; do
        case $arg in
            --verbose)
                VERBOSE=true
                LOG_LEVEL=3
                ;;
            --log-file=*)
                LOG_FILE="${arg#*=}"
                ;;
        esac
    done
}

# Initialize logger with optional parameters
# Usage: logger_init [--verbose] [--log-file=/path/to/log.log]
logger_init() {
    # First get caller info
    _get_caller_info
    
    # Process arguments
    _parse_args "$@"
    
    # Initialize log file
    _init_log_file
    
    # Log initialization
    log_info "Logger initialized for $CALLER_SCRIPT"
}

# Internal function to format and print log messages
# Usage: _log_print level color prefix message
_log_print() {
    local level=$1
    local color=$2
    local prefix=$3
    local message=$4
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Make sure we have caller info
    if [[ -z "$CALLER_SCRIPT" ]]; then
        _get_caller_info
    fi
    
    # Make sure we have a log file
    if [[ -z "$LOG_FILE" ]]; then
        _init_log_file
    fi
    
    # Format for console output (with colors)
    local console_msg="${color}${prefix}${NC} [${MAGENTA}${CALLER_SCRIPT}${NC}] ${message}"
    
    # Format for log file (no colors)
    local log_msg="${timestamp} ${prefix} [${CALLER_SCRIPT}] ${message}"
    
    # Always write to log file
    echo "$log_msg" >> "$LOG_FILE"
    
    # Check if we should display to console based on log level
    if [ "$level" -le "$LOG_LEVEL" ] || [ "$VERBOSE" = true ]; then
        echo -e "$console_msg"
    fi
}

# Log an error message
# Usage: log_error "Error message"
log_error() {
    _log_print 0 "$RED" "[ERROR]" "$1"
}

# Log a warning message
# Usage: log_warning "Warning message"
log_warning() {
    _log_print 1 "$YELLOW" "[WARNING]" "$1"
}

# Log an info message
# Usage: log_info "Info message"
log_info() {
    _log_print 2 "$GREEN" "[INFO]" "$1"
}

# Log a debug message (only shown when verbose is enabled)
# Usage: log_debug "Debug message"
log_debug() {
    _log_print 3 "$BLUE" "[DEBUG]" "$1"
}

# Log a success message
# Usage: log_success "Success message"
log_success() {
    _log_print 2 "$GREEN" "[SUCCESS]" "$1"
}

# Log a question and get user input
# Usage: log_question "Question?" [default_answer]
# Returns: User's answer in the global variable ANSWER
log_question() {
    local question=$1
    local default=${2:-}
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    
    # Make sure we have caller info and log file
    if [[ -z "$CALLER_SCRIPT" ]]; then
        _get_caller_info
    fi
    
    if [[ -z "$LOG_FILE" ]]; then
        _init_log_file
    fi
    
    ANSWER=""
    
    # Log the question to the log file
    echo "${timestamp} [QUESTION] [${CALLER_SCRIPT}] ${question}" >> "$LOG_FILE"
    
    # Display the question with colors to the console
    if [ -n "$default" ]; then
        echo -e "${CYAN}[QUESTION]${NC} [${MAGENTA}${CALLER_SCRIPT}${NC}] ${question} [${default}]: \c"
        read -r ANSWER
        if [ -z "$ANSWER" ]; then
            ANSWER="$default"
        fi
    else
        echo -e "${CYAN}[QUESTION]${NC} [${MAGENTA}${CALLER_SCRIPT}${NC}] ${question}: \c"
        read -r ANSWER
    fi
    
    # Log the answer
    echo "${timestamp} [ANSWER] [${CALLER_SCRIPT}] ${ANSWER}" >> "$LOG_FILE"
}

# Set verbosity
# Usage: logger_set_verbose true|false
logger_set_verbose() {
    VERBOSE=$1
    if [ "$VERBOSE" = true ]; then
        LOG_LEVEL=3
        log_debug "Verbose mode enabled"
    else
        LOG_LEVEL=2
        log_info "Verbose mode disabled"
    fi
}

# Set log level
# Usage: logger_set_level 0-3
logger_set_level() {
    local old_level=$LOG_LEVEL
    LOG_LEVEL=$1
    log_info "Log level changed from $old_level to $LOG_LEVEL"
}

# Set custom log file
# Usage: logger_set_log_file /path/to/logfile.log
logger_set_log_file() {
    local old_log_file=$LOG_FILE
    LOG_FILE=$1
    
    # Ensure log directory exists
    mkdir -p "$(dirname "$LOG_FILE")"
    
    # Log the change
    echo "Log file changed from $old_log_file to $LOG_FILE" >> "$old_log_file"
    echo "===== Log continued at $(date) =====" > "$LOG_FILE"
    echo "Script: $CALLER_SCRIPT" >> "$LOG_FILE"
    echo "Path: $CALLER_PATH" >> "$LOG_FILE"
    echo "===============================" >> "$LOG_FILE"
    
    log_info "Log file changed to $LOG_FILE"
}

# Display the log file path
# Usage: logger_get_log_file
logger_get_log_file() {
    echo "$LOG_FILE"
}

# Process any arguments passed during sourcing
_parse_args "$@"

# Initialize logger automatically
_get_caller_info
_init_log_file
