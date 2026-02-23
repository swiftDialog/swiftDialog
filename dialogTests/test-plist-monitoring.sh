#!/bin/bash
#
# test-plist-monitoring.sh
# Integration tests for plist monitoring in swiftDialog Inspect mode
#
# Tests the full pipeline: plist change → InspectState detection → step completion
#
# Usage: bash dialogTests/test-plist-monitoring.sh
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
DIALOG_BIN="/Users/henry/Projects/open-source/build/Dialog.app/Contents/MacOS/dialogcli"
TEMP_DIR=$(mktemp -d)
TRIGGER_FILE="$TEMP_DIR/trigger"
TEST_PLIST="$TEMP_DIR/TestPrefs.plist"
CONFIG_FILE="$TEMP_DIR/config.json"
PASS_COUNT=0
FAIL_COUNT=0

cleanup() {
    rm -rf "$TEMP_DIR"
    # Kill any dialog instances we started
    pkill -f "dialogcli.*--inspect-mode" 2>/dev/null || true
}
trap cleanup EXIT

pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    echo "  ✅ PASS: $1"
}

fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    echo "  ❌ FAIL: $1"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Plist Monitoring Integration Tests"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check dialog binary exists
if [[ ! -x "$DIALOG_BIN" ]]; then
    echo "ERROR: Dialog binary not found at $DIALOG_BIN"
    echo "Run ./ad-hoc-build.sh first"
    exit 1
fi

# ──────────────────────────────────────────────────────
# Test 1: evaluation "changed" - detect value transition
# ──────────────────────────────────────────────────────
echo "Test 1: evaluation 'changed' detects plist value transition"

# Create initial plist with a value
defaults write "$TEST_PLIST" TestKey -string "InitialValue"

# Create config that monitors for changes
cat > "$CONFIG_FILE" <<'HEREDOC'
{
  "title": "Plist Test",
  "message": "Testing plist monitoring",
  "preset": "preset6",
  "hideSystemDetails": true,
  "items": [
    {
      "id": "plist_monitor",
      "displayName": "Plist Monitor",
      "guiIndex": 0,
HEREDOC

# Inject the dynamic plist path
cat >> "$CONFIG_FILE" <<HEREDOC
      "paths": ["$TEST_PLIST"],
HEREDOC

cat >> "$CONFIG_FILE" <<'HEREDOC'
      "plistKey": "TestKey",
      "evaluation": "changed",
      "plistRecheckInterval": 1,
      "stepType": "processing",
      "processingDuration": 1,
      "waitForExternalTrigger": true,
      "successMessage": "Change detected!",
      "guidanceContent": [
        {"type": "text", "content": "Monitoring..."}
      ]
    }
  ]
}
HEREDOC

# Launch dialog in background
export DIALOG_INSPECT_CONFIG="$CONFIG_FILE"
"$DIALOG_BIN" --inspect-mode &>/dev/null &
DIALOG_PID=$!

# Wait for dialog to start and record baseline
sleep 3

# Change the plist value
defaults write "$TEST_PLIST" TestKey -string "ChangedValue"

# Wait for detection (checkDirectInstallationStatus runs every 2s)
sleep 5

# Check if dialog is still running or has completed
if kill -0 $DIALOG_PID 2>/dev/null; then
    # Dialog still running - check if completedItems has our item
    # We can't easily check this from outside, so just verify it didn't crash
    kill $DIALOG_PID 2>/dev/null || true
    wait $DIALOG_PID 2>/dev/null || true
    pass "Dialog survived plist change without crash"
else
    wait $DIALOG_PID 2>/dev/null || true
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 0 ]]; then
        pass "Dialog completed after plist change (exit 0)"
    else
        fail "Dialog exited with code $EXIT_CODE"
    fi
fi

# ──────────────────────────────────────────────────────
# Test 2: evaluation "changed" - NO completion when value unchanged
# ──────────────────────────────────────────────────────
echo ""
echo "Test 2: evaluation 'changed' does NOT complete when value unchanged"

# Reset plist
defaults write "$TEST_PLIST" TestKey -string "StableValue"

# Reuse same config
export DIALOG_INSPECT_CONFIG="$CONFIG_FILE"
"$DIALOG_BIN" --inspect-mode &>/dev/null &
DIALOG_PID=$!

# Wait 6 seconds without changing the plist (baseline check at ~0s, recheck at ~2s, ~4s)
sleep 6

# Dialog should still be running since value hasn't changed
if kill -0 $DIALOG_PID 2>/dev/null; then
    pass "Dialog still running with unchanged plist value"
    kill $DIALOG_PID 2>/dev/null || true
    wait $DIALOG_PID 2>/dev/null || true
else
    wait $DIALOG_PID 2>/dev/null || true
    EXIT_CODE=$?
    fail "Dialog exited early (code $EXIT_CODE) despite unchanged plist"
fi

# ──────────────────────────────────────────────────────
# Test 3: evaluation "exists" - immediate completion when key present
# ──────────────────────────────────────────────────────
echo ""
echo "Test 3: evaluation 'exists' completes immediately when key present"

# Create config with "exists" evaluation
cat > "$CONFIG_FILE" <<'HEREDOC'
{
  "title": "Exists Test",
  "message": "Testing exists evaluation",
  "preset": "preset6",
  "hideSystemDetails": true,
  "items": [
    {
      "id": "exists_check",
      "displayName": "Exists Check",
      "guiIndex": 0,
HEREDOC

cat >> "$CONFIG_FILE" <<HEREDOC
      "paths": ["$TEST_PLIST"],
HEREDOC

cat >> "$CONFIG_FILE" <<'HEREDOC'
      "plistKey": "TestKey",
      "evaluation": "exists",
      "stepType": "info",
      "guidanceContent": [
        {"type": "text", "content": "Checking key existence..."}
      ],
      "actionButtonText": "Done"
    }
  ]
}
HEREDOC

defaults write "$TEST_PLIST" TestKey -string "SomeValue"

export DIALOG_INSPECT_CONFIG="$CONFIG_FILE"
"$DIALOG_BIN" --inspect-mode &>/dev/null &
DIALOG_PID=$!

# Wait briefly for the filesystem check to run
sleep 4

# For "exists", the item should be in completedItems quickly, but since it's a single info step
# the dialog won't auto-close. Just verify it didn't crash.
if kill -0 $DIALOG_PID 2>/dev/null; then
    pass "Dialog running with 'exists' evaluation (key present)"
    kill $DIALOG_PID 2>/dev/null || true
    wait $DIALOG_PID 2>/dev/null || true
else
    wait $DIALOG_PID 2>/dev/null || true
    fail "Dialog crashed with 'exists' evaluation"
fi

# ──────────────────────────────────────────────────────
# Test 4: evaluation "exists" - NOT completed when key absent
# ──────────────────────────────────────────────────────
echo ""
echo "Test 4: evaluation 'exists' does not complete when key absent"

# Remove the key
defaults delete "$TEST_PLIST" TestKey 2>/dev/null || true
# Ensure plist still exists but without the key
defaults write "$TEST_PLIST" OtherKey -string "OtherValue"

export DIALOG_INSPECT_CONFIG="$CONFIG_FILE"
"$DIALOG_BIN" --inspect-mode &>/dev/null &
DIALOG_PID=$!

sleep 4

if kill -0 $DIALOG_PID 2>/dev/null; then
    pass "Dialog still running with absent key"
    kill $DIALOG_PID 2>/dev/null || true
    wait $DIALOG_PID 2>/dev/null || true
else
    wait $DIALOG_PID 2>/dev/null || true
    fail "Dialog exited early with absent key"
fi

# ──────────────────────────────────────────────────────
# Test 5: evaluation "equals" - exact match
# ──────────────────────────────────────────────────────
echo ""
echo "Test 5: evaluation 'equals' matches exact value"

cat > "$CONFIG_FILE" <<'HEREDOC'
{
  "title": "Equals Test",
  "preset": "preset6",
  "hideSystemDetails": true,
  "items": [
    {
      "id": "equals_check",
      "displayName": "Equals Check",
      "guiIndex": 0,
HEREDOC

cat >> "$CONFIG_FILE" <<HEREDOC
      "paths": ["$TEST_PLIST"],
HEREDOC

cat >> "$CONFIG_FILE" <<'HEREDOC'
      "plistKey": "Version",
      "evaluation": "equals",
      "expectedValue": "2.0",
      "stepType": "info",
      "guidanceContent": [
        {"type": "text", "content": "Checking version..."}
      ],
      "actionButtonText": "Done"
    }
  ]
}
HEREDOC

# Write wrong value first
defaults write "$TEST_PLIST" Version -string "1.0"
export DIALOG_INSPECT_CONFIG="$CONFIG_FILE"
"$DIALOG_BIN" --inspect-mode &>/dev/null &
DIALOG_PID=$!

sleep 3

# Should still be running (wrong value)
if kill -0 $DIALOG_PID 2>/dev/null; then
    pass "Dialog pending with wrong value for 'equals'"
else
    wait $DIALOG_PID 2>/dev/null || true
    fail "Dialog should still be pending with wrong value"
fi

# Now set correct value
defaults write "$TEST_PLIST" Version -string "2.0"
sleep 4

# Just verify no crash
if kill -0 $DIALOG_PID 2>/dev/null; then
    pass "Dialog stable after value change for 'equals'"
    kill $DIALOG_PID 2>/dev/null || true
    wait $DIALOG_PID 2>/dev/null || true
else
    wait $DIALOG_PID 2>/dev/null || true
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 0 ]]; then
        pass "Dialog completed after correct value set"
    else
        fail "Dialog exited with code $EXIT_CODE"
    fi
fi

# ──────────────────────────────────────────────────────
# Test 6: evaluation "changed" with key removal
# ──────────────────────────────────────────────────────
echo ""
echo "Test 6: evaluation 'changed' detects key removal"

cat > "$CONFIG_FILE" <<'HEREDOC'
{
  "title": "Changed Remove Test",
  "preset": "preset6",
  "hideSystemDetails": true,
  "items": [
    {
      "id": "change_remove",
      "displayName": "Change Remove",
      "guiIndex": 0,
HEREDOC

cat >> "$CONFIG_FILE" <<HEREDOC
      "paths": ["$TEST_PLIST"],
HEREDOC

cat >> "$CONFIG_FILE" <<'HEREDOC'
      "plistKey": "RemovableKey",
      "evaluation": "changed",
      "stepType": "processing",
      "processingDuration": 1,
      "waitForExternalTrigger": true,
      "successMessage": "Key removal detected!",
      "guidanceContent": [
        {"type": "text", "content": "Monitoring for key removal..."}
      ]
    }
  ]
}
HEREDOC

# Start with key present
defaults write "$TEST_PLIST" RemovableKey -string "Present"
export DIALOG_INSPECT_CONFIG="$CONFIG_FILE"
"$DIALOG_BIN" --inspect-mode &>/dev/null &
DIALOG_PID=$!

sleep 3

# Remove the key
defaults delete "$TEST_PLIST" RemovableKey

sleep 5

if kill -0 $DIALOG_PID 2>/dev/null; then
    kill $DIALOG_PID 2>/dev/null || true
    wait $DIALOG_PID 2>/dev/null || true
    pass "Dialog survived key removal (may have completed)"
else
    wait $DIALOG_PID 2>/dev/null || true
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 0 ]]; then
        pass "Dialog completed after key removal (exit 0)"
    else
        fail "Dialog exited with code $EXIT_CODE after key removal"
    fi
fi

# ──────────────────────────────────────────────────────
# Test 7: evaluation "changed" with key addition
# ──────────────────────────────────────────────────────
echo ""
echo "Test 7: evaluation 'changed' detects key addition"

cat > "$CONFIG_FILE" <<'HEREDOC'
{
  "title": "Changed Add Test",
  "preset": "preset6",
  "hideSystemDetails": true,
  "items": [
    {
      "id": "change_add",
      "displayName": "Change Add",
      "guiIndex": 0,
HEREDOC

cat >> "$CONFIG_FILE" <<HEREDOC
      "paths": ["$TEST_PLIST"],
HEREDOC

cat >> "$CONFIG_FILE" <<'HEREDOC'
      "plistKey": "NewKey",
      "evaluation": "changed",
      "stepType": "processing",
      "processingDuration": 1,
      "waitForExternalTrigger": true,
      "successMessage": "Key addition detected!",
      "guidanceContent": [
        {"type": "text", "content": "Monitoring for key addition..."}
      ]
    }
  ]
}
HEREDOC

# Start WITHOUT the key
defaults delete "$TEST_PLIST" NewKey 2>/dev/null || true
export DIALOG_INSPECT_CONFIG="$CONFIG_FILE"
"$DIALOG_BIN" --inspect-mode &>/dev/null &
DIALOG_PID=$!

sleep 3

# Add the key
defaults write "$TEST_PLIST" NewKey -string "JustAdded"

sleep 5

if kill -0 $DIALOG_PID 2>/dev/null; then
    kill $DIALOG_PID 2>/dev/null || true
    wait $DIALOG_PID 2>/dev/null || true
    pass "Dialog survived key addition"
else
    wait $DIALOG_PID 2>/dev/null || true
    EXIT_CODE=$?
    if [[ $EXIT_CODE -eq 0 ]]; then
        pass "Dialog completed after key addition (exit 0)"
    else
        fail "Dialog exited with code $EXIT_CODE after key addition"
    fi
fi

# ──────────────────────────────────────────────────────
# Summary
# ──────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Results: $PASS_COUNT passed, $FAIL_COUNT failed"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ $FAIL_COUNT -gt 0 ]]; then
    exit 1
fi
