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

INCOMPLETE_PHASES="$(grep -E -c '\*\*Status:\*\*\s*(pending|in_progress)' "$PLAN" 2>/dev/null || true)"
INCOMPLETE_PHASES="${INCOMPLETE_PHASES:-0}"
if [ "$INCOMPLETE_PHASES" -gt 0 ]; then
    block_stop "Project Spine feature '${SLUG}' still has ${INCOMPLETE_PHASES} incomplete phase(s) in ${PLAN}. Finish the active phase or mark the plan accurately before stopping."
fi

UNCHECKED_TASKS="$(grep -E -c '^[[:space:]]*-[[:space:]]+\[[[:space:]]\]' "$PLAN" 2>/dev/null || true)"
UNCHECKED_TASKS="${UNCHECKED_TASKS:-0}"
if [ "$UNCHECKED_TASKS" -gt 0 ]; then
    block_stop "Project Spine feature '${SLUG}' still has ${UNCHECKED_TASKS} unchecked task(s) in ${PLAN}. Either complete them or update the plan before stopping."
fi

exit 0
