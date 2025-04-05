#!/bin/bash

# Source error handler
SCRIPT_DIR_RELATIVE_PATH=$(dirname "$0")
ERROR_HANDLER_SCRIPT="$SCRIPT_DIR_RELATIVE_PATH/../misc/error_handler.sh"
# shellcheck disable=SC1090
source "$ERROR_HANDLER_SCRIPT" || { echo "Error: Could not source error_handler.sh" >&2; exit 1; }
setup_error_handling

log_info "Preparing SSH key for Coolify installation..."

# Generate a temporary SSH key without passphrase
TEMP_SSH_KEY="$HOME/.ssh/id_rsa_coolify_temp"
log_info "Generating temporary SSH key without passphrase at $TEMP_SSH_KEY"
ssh-keygen -t rsa -b 4096 -f "$TEMP_SSH_KEY" -N "" || log_fatal "Failed to generate SSH key"

# Display the public key
log_info "Here is the public key to use during Raspberry Pi OS setup:"
echo ""
cat "${TEMP_SSH_KEY}.pub"
echo ""

log_info "Copy this public key and use it when configuring SSH during Raspberry Pi OS installation."
log_warn "IMPORTANT: After Coolify installation is complete, you should remove this temporary key for security."
log_info "To remove the temporary key after installation: rm ${TEMP_SSH_KEY}*"

exit 0