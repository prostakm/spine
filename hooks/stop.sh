#!/usr/bin/env bash
# Project Spine: Stop hook
# Verifies all phases are complete before allowing the agent to stop.
# Returns non-zero exit + message if phases remain incomplete.

SPINE_DIR=".spine"
ACTIVE_FILE="${SPINE_DIR}/active-feature"

if [ ! -f "$ACTIVE_FILE" ]; then
    exit 0  # No active feature, allow stop
fi

SLUG=$(cat "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
if [ -z "$SLUG" ]; then
    exit 0
fi

PLAN="${SPINE_DIR}/features/${SLUG}/plan.md"
if [ ! -f "$PLAN" ]; then
    exit 0
fi

# Count incomplete phases (lines with "Status:** pending" or "Status:** in_progress")
INCOMPLETE=$(grep -c -E '\*\*Status:\*\*\s*(pending|in_progress)' "$PLAN" 2>/dev/null)

if [ "$INCOMPLETE" -gt 0 ]; then
    echo "STOP BLOCKED: ${INCOMPLETE} phase(s) still incomplete in ${PLAN}."
    echo "Complete all phases before stopping, or update plan.md to reflect current state."
    exit 1
fi

exit 0
