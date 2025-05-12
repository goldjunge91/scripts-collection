#!/bin/bash
# logger.sh - A modular logger for shell scripts
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
NC='\033[0m' # No Color

# Initialize logger with optional verbosity
# Usage: logger_init [--verbose]
logger_init() {
    for arg in "$@"; do
        case $arg in
            --verbose)
                VERBOSE=true
                LOG_LEVEL=3
                ;;
        esac
    done
}

# Internal function to format and print log messages
# Usage: _log_print level color prefix message
_log_print() {
    local level=$1
    local color=$2
    local prefix=$3
    local message=$4
    
    if [ "$level" -le "$LOG_LEVEL" ]; then
        if [ "$VERBOSE" = true ] || [ "$level" -le 2 ]; then
            echo -e "${color}${prefix}${NC} ${message}"
        fi
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
    
    ANSWER=""
    
    if [ -n "$default" ]; then
        echo -e "${CYAN}[QUESTION]${NC} ${question} [${default}]: \c"
        read -r ANSWER
        if [ -z "$ANSWER" ]; then
            ANSWER="$default"
        fi
    else
        echo -e "${CYAN}[QUESTION]${NC} ${question}: \c"
        read -r ANSWER
    fi
}

# Set verbosity
# Usage: logger_set_verbose true|false
logger_set_verbose() {
    VERBOSE=$1
    if [ "$VERBOSE" = true ]; then
        LOG_LEVEL=3
    else
        LOG_LEVEL=2
    fi
}

# Set log level
# Usage: logger_set_level 0-3
logger_set_level() {
    LOG_LEVEL=$1
}
