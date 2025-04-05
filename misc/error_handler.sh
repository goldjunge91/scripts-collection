#!/bin/bash

# ==============================================================================
# Modular Bash Error Handler with Logging and Debug Support
#
# Usage:
# 1. Source this script: source error_handler.sh
# 2. Optionally set config variables (BEFORE calling setup):
#    export ERROR_LOG_FILE="/path/to/your/custom.log" # Default: script_name.log in script dir or /tmp
#    export DEBUG=1                                    # Default: 0 (off)
# 3. Initialize: setup_error_handling
# 4. Use logging functions: log_info, log_warn, log_error, log_debug, log_fatal
# ==============================================================================

# --- Default Configuration ---
# If ERROR_LOG_FILE is not set externally, determine a default path
: "${ERROR_LOG_FILE:=""}"
# If DEBUG is not set externally, default to 0 (off)
: "${DEBUG:=0}"

# --- Internal Variables ---
_SCRIPT_NAME=""
_SCRIPT_DIR=""
_ERROR_HANDLER_INITIALIZED=0

# --- Colors for Output (optional) ---
# Check if stdout is a terminal
if [ -t 1 ]; then
    _COLOR_RESET="\033[0m"
    _COLOR_RED="\033[0;31m"
    _COLOR_YELLOW="\033[0;33m"
    _COLOR_BLUE="\033[0;34m"
    _COLOR_GRAY="\033[0;90m"
else
    _COLOR_RESET=""
    _COLOR_RED=""
    _COLOR_YELLOW=""
    _COLOR_BLUE=""
    _COLOR_GRAY=""
fi

# --- Logging Functions ---

# Internal function to write log messages
_write_log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    # Ensure log file is set
    if [[ -z "$ERROR_LOG_FILE" ]]; then
        echo "[$(date '+%H:%M:%S')] [ERROR_HANDLER] ERROR: Log file path not set. Cannot log message: $level - $message" >&2
        return 1
    fi
    # Ensure log directory exists
    local log_dir
    log_dir=$(dirname "$ERROR_LOG_FILE")
    if [[ ! -d "$log_dir" ]]; then
        mkdir -p "$log_dir" || {
            echo "[$(date '+%H:%M:%S')] [ERROR_HANDLER] ERROR: Failed to create log directory '$log_dir'. Cannot log message." >&2
            return 1
        }
    fi
    # Append to log file
    echo "[$timestamp] [$level] [${_SCRIPT_NAME}] $message" >> "$ERROR_LOG_FILE"
}

# Log informational messages
log_info() {
    local message="$*"
    echo -e "${_COLOR_BLUE}INFO:${_COLOR_RESET}  $message"
    _write_log "INFO" "$message"
}

# Log warning messages
log_warn() {
    local message="$*"
    echo -e "${_COLOR_YELLOW}WARN:${_COLOR_RESET}  $message" >&2
    _write_log "WARN" "$message"
}

# Log error messages (does not exit)
log_error() {
    local message="$*"
    echo -e "${_COLOR_RED}ERROR:${_COLOR_RESET} $message" >&2
    _write_log "ERROR" "$message"
}

# Log fatal errors and exit
log_fatal() {
    local message="$*"
    local exit_code="${2:-1}" # Use provided exit code or default to 1
    echo -e "${_COLOR_RED}FATAL:${_COLOR_RESET} $message" >&2
    _write_log "FATAL" "$message"
    exit "$exit_code"
}

# Log debug messages (only if DEBUG=1)
log_debug() {
    if [[ "$DEBUG" -eq 1 ]]; then
        local message="$*"
        # Get caller info for better debugging context
        local caller_info="${BASH_SOURCE[1]}:${FUNCNAME[1]}:${BASH_LINENO[0]}"
        echo -e "${_COLOR_GRAY}DEBUG: [$caller_info] $message${_COLOR_RESET}" >&2
        _write_log "DEBUG" "[$caller_info] $message"
    fi
}

# --- Error Handling Function ---

# Called by 'trap ERR'
_handle_error() {
    local exit_code=$?
    local line_number=$1 # Line number is passed as the first argument from the trap
    local command="${BASH_COMMAND:-unknown command}" # Command that failed (may not always be accurate)

    # Build call stack
    local stack_depth=${#FUNCNAME[@]}
    local call_stack=""
    # Start from 1 to skip _handle_error itself
    for ((i = 1; i < stack_depth; i++)); do
        local func="${FUNCNAME[$i]}"
        local line="${BASH_LINENO[$((i - 1))]}"
        local src="${BASH_SOURCE[$i]}"
        # Indentation for readability
        local indent=""
        for ((j=1; j<i; j++)); do indent+="  "; done
        call_stack+="\n${indent}in function '$func' (${src}:${line})"
    done
    [[ -z "$call_stack" ]] && call_stack=" in main script scope (${BASH_SOURCE[0]})"


    local error_message="Script error encountered!"
    local log_message="Error (Exit Code: $exit_code) on line $line_number. Command: '$command'. Call Stack:${call_stack}"

    echo -e "${_COLOR_RED}ERROR:${_COLOR_RESET} $error_message" >&2
    echo -e "  ${_COLOR_RED}Exit Code:${_COLOR_RESET} $exit_code" >&2
    echo -e "  ${_COLOR_RED}Line:${_COLOR_RESET}      $line_number (${BASH_SOURCE[0]})" >&2
    echo -e "  ${_COLOR_RED}Command:${_COLOR_RESET}   '$command'" >&2
    echo -e "  ${_COLOR_RED}Call Stack:${_COLOR_RESET}${call_stack}" >&2

    _write_log "ERROR" "$log_message"

    # Optional: Add cleanup logic here if needed before exiting

    # Exit with the original error code
    exit "$exit_code"
}

# --- Setup Function ---

setup_error_handling() {
    if [[ "$_ERROR_HANDLER_INITIALIZED" -eq 1 ]]; then
        log_warn "Error handler already initialized."
        return 0
    fi

    # Determine script name and directory (relative to the script using the handler)
    # $0 might be the handler itself if sourced directly, need to check BASH_SOURCE
    if [[ -n "${BASH_SOURCE[1]}" ]]; then
      _SCRIPT_NAME=$(basename "${BASH_SOURCE[1]}")
      _SCRIPT_DIR=$(dirname "$(realpath "${BASH_SOURCE[1]}")")
    else
      _SCRIPT_NAME=$(basename "$0")
      _SCRIPT_DIR=$(dirname "$(realpath "$0")")
    fi


    # Set default log file path if not provided externally
    if [[ -z "$ERROR_LOG_FILE" ]]; then
        # Try to create log in script directory, fallback to /tmp
        if [[ -w "$_SCRIPT_DIR" ]]; then
            ERROR_LOG_FILE="$_SCRIPT_DIR/${_SCRIPT_NAME%.*}.log"
        else
            ERROR_LOG_FILE="/tmp/${_SCRIPT_NAME%.*}.log"
            log_warn "Cannot write to script directory '$_SCRIPT_DIR'. Using log file '$ERROR_LOG_FILE'."
        fi
    fi

    # Bash strict mode and error trapping
    # errexit: Exit immediately if a command exits with a non-zero status.
    # nounset: Treat unset variables as an error when substituting.
    # pipefail: Return value of a pipeline is the status of the last command to exit with non-zero status, or zero if no command failed.
    set -Eeuo pipefail

    # Trap ERR signal to call our handler function, passing the line number
    # Use -E (same as `set -o errtrace`) to ensure ERR trap is inherited by functions, command substitutions, and subshells
    trap '_handle_error $LINENO' ERR

    # Optional: Trap EXIT signal for cleanup or logging end-of-script
    # trap '_handle_exit' EXIT

    _ERROR_HANDLER_INITIALIZED=1
    log_debug "Error handler initialized. Script: '$_SCRIPT_NAME'. Log file: '$ERROR_LOG_FILE'. Debug: $DEBUG."
    log_info "Error handling setup complete. Logging to: $ERROR_LOG_FILE"
}

# Optional: Exit handler function
# _handle_exit() {
#   local exit_code=$?
#   if [[ $exit_code -ne 0 && "$_ERROR_HANDLER_INITIALIZED" -eq 1 ]]; then
#      # Error was likely handled by _handle_error already unless trap ERR was unset
#      log_debug "Script exiting with non-zero code: $exit_code (might be handled by ERR trap)"
#   elif [[ "$_ERROR_HANDLER_INITIALIZED" -eq 1 ]]; then
#      log_info "Script completed successfully."
#   fi
#   # Add cleanup tasks here if needed
# }

# Make functions available for export if sourced
export -f log_info log_warn log_error log_fatal log_debug setup_error_handling