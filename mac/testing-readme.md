# Node Modules Cleanup Tests

Simple test suite for the `cleanup-node-modules.sh` script.

## Running the Tests

1. Make sure all files are in `/Users/marco/Github/scripts-collection/mac`:
   - `cleanup-node-modules.sh` (main script)
   - `logger.sh` (logging module)
   - `tests-bats.sh` (test file)
   - `test-runner.sh` (test runner)

2. Run the tests:
   ```bash
   cd /Users/marco/Github/scripts-collection/mac
   ./test-runner.sh
   ```

This will install BATS if it's not already installed, then run all the tests.

## Test Cases

The tests verify:

1. Finding node_modules directories
2. Dry-run mode (no deletion)
3. Directory parameter functionality
4. Handling directories without node_modules
5. Deletion with "yes" confirmation
6. No deletion with "no" confirmation
7. Verbose mode output

## Customizing

If your scripts are located in a different directory, update the paths in:
- `cleanup-node-modules.bats` (SCRIPT_PATH and LOGGER_PATH variables)
- `run-tests.sh` (SCRIPT_DIR variable)
