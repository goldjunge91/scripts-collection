#!/usr/bin/env bash
# Helper script for loading BATS plugins

# Get the directory of this script
FRAMEWORKS_DIR="$(dirname "$BASH_SOURCE")"

# Fixed paths to the plugins
BATS_SUPPORT_DIR="${FRAMEWORKS_DIR}/bats-support"
BATS_ASSERT_DIR="${FRAMEWORKS_DIR}/bats-assert"

load_bats_support() {
  if [ -f "${BATS_SUPPORT_DIR}/load.bash" ]; then
    load "${BATS_SUPPORT_DIR}/load.bash"
  else
    echo "WARNING: bats-support not found at ${BATS_SUPPORT_DIR}"
    return 1
  fi
}

load_bats_assert() {
  if [ -f "${BATS_ASSERT_DIR}/load.bash" ]; then
    load "${BATS_ASSERT_DIR}/load.bash"
  else
    echo "WARNING: bats-assert not found at ${BATS_ASSERT_DIR}"
    return 1
  fi
}
