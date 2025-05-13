#!/bin/bash
# run-all-tests.sh - Run all tests with configurable options
# Usage: ./run-all-tests.sh [--perm|--temp] [--clean|--noclean]

# Get the directory of this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Define color codes
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Default options
TEST_MODE="temp"
CLEAN_MODE="clean"

# Parse command line arguments
for arg in "$@"; do
    case $arg in
        --perm)
            TEST_MODE="perm"
            shift
            ;;
        --temp)
            TEST_MODE="temp"
            shift
            ;;
        --clean)
            CLEAN_MODE="clean"
            shift
            ;;
        --noclean)
            CLEAN_MODE="noclean"
            shift
            ;;
        --help)
            echo "Usage: $0 [--perm|--temp] [--clean|--noclean]"
            echo ""
            echo "Options:"
            echo "  --perm      Use permanent test directories (default: temp)"
            echo "  --temp      Use temporary test directories"
            echo "  --clean     Clean up test directories after tests (default)"
            echo "  --noclean   Keep test directories for inspection"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}Running all tests with:${NC}"
echo -e "${MAGENTA}Test directory mode:${NC} $TEST_MODE"
echo -e "${MAGENTA}Cleanup mode:${NC} $CLEAN_MODE"
echo ""

# Export test configuration variables
export TEST_DIR_MODE="$TEST_MODE"
export TEST_DIR_CLEAN="$CLEAN_MODE"

# List of all test files
TEST_FILES=(
    "$SCRIPT_DIR/cleanup-node-modules.bats"
    "$SCRIPT_DIR/logger.bats"
)

# Run each test file
for test_file in "${TEST_FILES[@]}"; do
    if [ -f "$test_file" ]; then
        echo -e "${GREEN}Running tests in:${NC} $(basename "$test_file")"
        
        # Run the test with the configured options
        TEST_DIR_MODE="$TEST_MODE" TEST_DIR_CLEAN="$CLEAN_MODE" bats "$test_file"
        
        echo ""
    else
        echo -e "${RED}Test file not found:${NC} $test_file"
    fi
done

echo -e "${GREEN}All tests completed!${NC}"
