#!/bin/bash

# Konfiguration
# --- IMPORTANT: Set this to the correct mount point of your external drive ---
MOUNT_POINT="/Volumes/TimeMachine"
# --- You can adjust the volume name for clarity if needed ---
VOLUME_NAME="External Drive" # Descriptive name for notifications

echo "Starting check for ${VOLUME_NAME} at ${MOUNT_POINT}..."

# Speicherbelegung holen (Get disk usage)
# Use df -P to prevent line wrapping, -h for human-readable (though we only use percentage)
# Target the specific mount point, get the second line (NR==2), print the 5th field ($5), remove '%'
df_output_percent=$(df -Ph "$MOUNT_POINT" | awk 'NR==2 {print $5}')
echo "Debug: Raw percentage value from df: '$df_output_percent'" # Debug output
used_percent=$(echo "$df_output_percent" | tr -d '%')
echo "Debug: Calculated used percentage: '$used_percent'" # Debug output

# Check if used_percent is actually a number
if [[ "$used_percent" =~ ^[0-9]+$ ]]; then
  # Always display the current usage percentage via notification and terminal
  echo "Success: ${VOLUME_NAME} usage at ${used_percent}% (Mount: ${MOUNT_POINT})"
  # Use osascript to show a macOS notification
  osascript -e "display notification \"${VOLUME_NAME} usage at ${used_percent}%\" with title \"${VOLUME_NAME} Status\" subtitle \"Mount: ${MOUNT_POINT}\" sound name \"Glass\""

  # Optional: Add a separate warning if a threshold is exceeded
  THRESHOLD_PERCENT=90
  if [[ "$used_percent" -ge "$THRESHOLD_PERCENT" ]]; then
    echo "Warning: ${VOLUME_NAME} usage is high: ${used_percent}% (Threshold: ${THRESHOLD_PERCENT}%)"
    osascript -e "display notification \"${VOLUME_NAME} usage is high: ${used_percent}%\" with title \"${VOLUME_NAME} Warning\" sound name \"Frog\""
  fi

elif [[ -z "$used_percent" ]] && ! mount | grep -q " on ${MOUNT_POINT} "; then
  # Handle specific error: Drive not mounted
  # Output error to stderr and also try notification
  echo "Error: Drive not mounted at $MOUNT_POINT." >&2
  osascript -e "display notification \"Drive not found at ${MOUNT_POINT}.\" with title \"${VOLUME_NAME} Check Error\" sound name \"Basso\""
else
  # Handle general error: used_percent is not a number or df failed
  # Output error to stderr and also try notification
  echo "Error: Could not determine usage percentage for $MOUNT_POINT. Value found: '$used_percent'" >&2
  osascript -e "display notification \"Could not determine usage for ${MOUNT_POINT}.\" with title \"${VOLUME_NAME} Check Error\" sound name \"Basso\""
fi

echo "Check finished for ${VOLUME_NAME}."
