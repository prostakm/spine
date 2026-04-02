#!/usr/bin/env bash
# Project Spine: Stop hook
# Checks for incomplete work before allowing stop.
# Works with phased plans (Status: pending/in_progress) and flat plans (unchecked [ ] tasks).

SPINE_DIR=".spine"
ACTIVE_FILE="${SPINE_DIR}/active-feature"

[ ! -f "$ACTIVE_FILE" ] && exit 0

SLUG=$(cat "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
[ -z "$SLUG" ] && exit 0

PLAN="${SPINE_DIR}/features/${SLUG}/plan.md"
[ ! -f "$PLAN" ] && exit 0

INCOMPLETE=$(grep -E -c '\*\*Status:\*\*\s*(pending|in_progress)' "$PLAN" 2>/dev/null || true)
[ -z "$INCOMPLETE" ] && INCOMPLETE=0
if [ "$INCOMPLETE" -gt 0 ]; then
    printf '{"continue":false,"stopReason":"%s phase(s) incomplete in %s.","suppressOutput":false}\n' "$INCOMPLETE" "$PLAN"
    exit 0
fi

UNCHECKED=$(grep -E -c '^\s*- \[ \]' "$PLAN" 2>/dev/null || true)
[ -z "$UNCHECKED" ] && UNCHECKED=0
if [ "$UNCHECKED" -gt 0 ]; then
    printf '{"continue":false,"stopReason":"%s unchecked task(s) remain in %s.","suppressOutput":false}\n' "$UNCHECKED" "$PLAN"
    exit 0
fi

exit 0
