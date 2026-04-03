#!/usr/bin/env bash
# Project Spine: PostToolUse hook
# Emits structured reminders after Bash tool calls when a Spine feature is active.

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
    printf '{"hookSpecificOutput":{"hookEventName":"PostToolUse","additionalContext":"%s"}}\n' "$(json_escape "$message")"
}

[ -f "$ACTIVE_FILE" ] || exit 0

SLUG="$(tr -d '[:space:]' < "$ACTIVE_FILE" 2>/dev/null || true)"
[ -n "$SLUG" ] || exit 0

PLAN="${SPINE_DIR}/features/${SLUG}/plan.md"
LOG_FILE="${SPINE_DIR}/features/${SLUG}/log.md"
FINDINGS="${SPINE_DIR}/features/${SLUG}/findings.md"
[ -f "$PLAN" ] || exit 0

MESSAGE=$(
    cat <<EOF
Active Project Spine feature: ${SLUG}
If this Bash command changed project state, update ${PLAN} and ${LOG_FILE}.
If you just finished a research pair, update ${FINDINGS}.
Do not start the next plan phase until the current phase status is accurate.
EOF
)

emit_context "$MESSAGE"
