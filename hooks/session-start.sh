#!/usr/bin/env bash
# Project Spine: SessionStart hook
# Emits structured recovery context for startup/resume events.

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
    printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$(json_escape "$message")"
}

append_excerpt() {
    local file="$1"
    local max_lines="$2"
    [ -f "$file" ] || return 0

    local excerpt
    excerpt="$(sed -n "1,${max_lines}p" "$file" 2>/dev/null || true)"
    [ -n "$excerpt" ] || return 0

    CONTEXT="${CONTEXT}--- ${file} ---"$'\n'"${excerpt}"$'\n\n'
}

[ -d "$SPINE_DIR" ] || exit 0

CONTEXT="Project Spine session context"$'\n\n'

append_excerpt "${SPINE_DIR}/project.md" 40
append_excerpt "${SPINE_DIR}/conventions.md" 40
append_excerpt "${SPINE_DIR}/progress.md" 40

if [ -f "$ACTIVE_FILE" ]; then
    SLUG="$(tr -d '[:space:]' < "$ACTIVE_FILE" 2>/dev/null || true)"
    if [ -n "$SLUG" ]; then
        CONTEXT="${CONTEXT}Active feature: ${SLUG}"$'\n\n'
        append_excerpt "${SPINE_DIR}/features/${SLUG}/spec.md" 40
        append_excerpt "${SPINE_DIR}/features/${SLUG}/plan.md" 60
        append_excerpt "${SPINE_DIR}/features/${SLUG}/findings.md" 40
        append_excerpt "${SPINE_DIR}/features/${SLUG}/log.md" 40
    fi
fi

emit_context "$CONTEXT"
