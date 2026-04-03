#!/usr/bin/env bash
# Project Spine: PreToolUse hook
# Emits structured context for Bash tool calls when a Spine feature is active.

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

emit_context() {
    local message="$1"
    [ -n "$message" ] || exit 0
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"%s"}}\n' "$(json_escape "$message")"
}

[ -f "$ACTIVE_FILE" ] || exit 0

SLUG="$(tr -d '[:space:]' < "$ACTIVE_FILE" 2>/dev/null || true)"
[ -n "$SLUG" ] || exit 0

PLAN="${SPINE_DIR}/features/${SLUG}/plan.md"
[ -f "$PLAN" ] || exit 0

FINDINGS="${SPINE_DIR}/features/${SLUG}/findings.md"
LOG_FILE="${SPINE_DIR}/features/${SLUG}/log.md"

MESSAGE=$(
    cat <<EOF
Active Project Spine feature: ${SLUG}
Plan: ${PLAN}
Check the current phase before running Bash.
If you are still researching, follow the 2-Action Rule and update ${FINDINGS} after every 2 read/search operations.
If this command is implementation work, keep ${LOG_FILE} aligned with completed tasks.
EOF
)

emit_context "$MESSAGE"
