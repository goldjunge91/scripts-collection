#!/usr/bin/env bash
# Helper script to load BATS plugins from custom location

FRAMEWORKS_DIR="/Users/marco/Github.tmp/scripts-collection/frameworks"
BATS_SUPPORT_DIR="${FRAMEWORKS_DIR}/bats/bats-support"
BATS_ASSERT_DIR="${FRAMEWORKS_DIR}/bats/bats-assert"

load_bats_support() {
  # Check if the directory exists
  if [ -d "$BATS_SUPPORT_DIR" ]; then
    load "$BATS_SUPPORT_DIR/load.bash"
  else
    echo "WARNING: bats-support not found at $BATS_SUPPORT_DIR"
    return 1
  fi
}

load_bats_assert() {
  # Check if the directory exists
  if [ -d "$BATS_ASSERT_DIR" ]; then
    load "$BATS_ASSERT_DIR/load.bash"
  else
    echo "WARNING: bats-assert not found at $BATS_ASSERT_DIR"
    return 1
  fi
}
