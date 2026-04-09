#!/usr/bin/env bash
# Project Spine: Stop hook
# Blocks session stop while active feature work remains incomplete.

set -euo pipefail

SPINE_DIR=".spine"
ACTIVE_FILE="${SPINE_DIR}/active-feature"

json_escape() {
    local value="${1:-}"
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '%s' "$value"
}

block_stop() {
    local reason="$1"
    printf '{"decision":"block","reason":"%s"}\n' "$(json_escape "$reason")"
    exit 0
}

[ -f "$ACTIVE_FILE" ] || exit 0

SLUG="$(tr -d '[:space:]' < "$ACTIVE_FILE" 2>/dev/null || true)"
[ -n "$SLUG" ] || exit 0

PLAN="${SPINE_DIR}/features/${SLUG}/plan.md"
[ -f "$PLAN" ] || exit 0

STATE_PHASE="$(awk '
    /^## State$/ { in_state = 1; next }
    in_state && /^## / { exit }
    in_state && /^[[:space:]]*-[[:space:]]*Phase:[[:space:]]*/ {
        sub(/^[[:space:]]*-[[:space:]]*Phase:[[:space:]]*/, "", $0)
        print tolower($0)
        exit
    }
' "$PLAN" 2>/dev/null || true)"

STATE_PHASE="${STATE_PHASE:-}"
if [ -z "$STATE_PHASE" ] || [ "$STATE_PHASE" = "planning" ]; then
    exit 0
fi

UNCHECKED_TASKS="$(grep -E -c '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' "$PLAN" 2>/dev/null || true)"
UNCHECKED_TASKS="${UNCHECKED_TASKS:-0}"
if [ "$UNCHECKED_TASKS" -gt 0 ]; then
    block_stop "Project Spine feature '${SLUG}' still has ${UNCHECKED_TASKS} unchecked task(s) in ${PLAN}. Complete the acceptance gate or update the plan before stopping."
fi

exit 0
