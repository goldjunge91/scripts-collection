#!/bin/bash
# cleanup-node-modules.sh - Find and optionally delete node_modules directories
# Usage: ./cleanup-node-modules.sh [directory] [--dry-run] [--verbose]

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source the logger module
source "$SCRIPT_DIR/logger.sh"

# Default values
SEARCH_DIR="."
DRY_RUN=false
TOTAL_SIZE=0
UNIT_SUFFIX="B"
DIRS_TO_DELETE=()
SIZES_TO_DISPLAY=()

# Function to print usage information
print_usage() {
    echo "Usage: $0 [directory] [--dry-run] [--verbose]"
    echo ""
    echo "Options:"
    echo "  directory   Directory to search for node_modules (default: current directory)"
    echo "  --dry-run   Show what would be done without actually deleting"
    echo "  --verbose   Show detailed output"
    echo ""
    exit 1
}

# Function to convert bytes to human-readable format
format_size() {
    local size=$1
    local power=0
    local units=("B" "K" "M" "G" "T")
    
    while (( size >= 1024 )); do
        size=$(echo "scale=1; $size / 1024" | bc)
        power=$((power + 1))
    done
    
    # Round to one decimal place
    size=$(printf "%.1f" $size)
    echo "${size}${units[$power]}"
}

# Function to add size to total
add_to_total() {
    local size_in_bytes=$1
    TOTAL_SIZE=$((TOTAL_SIZE + size_in_bytes))
}

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --help|-h)
            print_usage
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --verbose)
            logger_set_verbose true
            ;;
        --*)
            log_error "Unknown option: $arg"
            print_usage
            ;;
        *)
            if [ "$arg" != "$0" ]; then
                SEARCH_DIR="$arg"
            fi
            ;;
    esac
done

# Log start of script
log_info "Starting search for node_modules directories in '$SEARCH_DIR'"
if [ "$DRY_RUN" = true ]; then
    log_info "Running in dry-run mode (no files will be deleted)"
fi

# Find all node_modules directories and calculate their sizes
log_debug "Finding node_modules directories..."

while IFS= read -r dir; do
    if [ -d "$dir" ]; then
        # Get size in bytes
        size_in_bytes=$(du -sb "$dir" | cut -f1)
        # Format size for display
        size_formatted=$(du -sh "$dir" | cut -f1)
        
        # Add to our arrays
        DIRS_TO_DELETE+=("$dir")
        SIZES_TO_DISPLAY+=("$size_formatted	$dir")
        
        # Add to total
        add_to_total "$size_in_bytes"
        
        log_debug "Found: $dir ($size_formatted)"
    fi
done < <(find "$SEARCH_DIR" -name node_modules -type d -prune)

# If no directories found
if [ ${#DIRS_TO_DELETE[@]} -eq 0 ]; then
    log_info "No node_modules directories found in '$SEARCH_DIR'"
    exit 0
fi

# Display the list of found node_modules directories
log_info "Found ${#DIRS_TO_DELETE[@]} node_modules directories:"
echo ""

# Print the table of directories and sizes
for size_and_dir in "${SIZES_TO_DISPLAY[@]}"; do
    echo " $size_and_dir"
done

# Print the total size
total_formatted=$(format_size $TOTAL_SIZE)
echo " $total_formatted	total"
echo ""

# Ask for confirmation
if [ "$DRY_RUN" = true ]; then
    log_info "Dry run - would have asked to delete ${#DIRS_TO_DELETE[@]} directories totaling $total_formatted"
    exit 0
fi

log_question "Do you want to delete these directories? (yes/no)" "no"

# Process confirmation
if [[ "$ANSWER" =~ ^[Yy][Ee][Ss]$ ]]; then
    log_info "Deleting ${#DIRS_TO_DELETE[@]} node_modules directories..."
    
    # Delete each directory
    for dir in "${DIRS_TO_DELETE[@]}"; do
        log_debug "Deleting: $dir"
        
        if command -v trash &> /dev/null; then
            # Use trash command if available
            trash "$dir" && log_debug "Trashed: $dir" || log_error "Failed to trash: $dir"
        else
            # Fall back to rm -rf
            rm -rf "$dir" && log_debug "Deleted: $dir" || log_error "Failed to delete: $dir"
        fi
    done
    
    log_success "Successfully cleaned up ${#DIRS_TO_DELETE[@]} node_modules directories, freeing approximately $total_formatted of disk space"
else
    log_info "Operation cancelled. No directories were deleted."
fi

exit 0
