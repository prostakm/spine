#!/usr/bin/env bash
# Project Spine: SessionStart hook
# Emits compact recovery state for startup/resume events.

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

section_field() {
    local file="$1"
    local heading="$2"
    local field="$3"
    [ -f "$file" ] || return 0

    awk -v heading="$heading" -v field="$field" '
        $0 == "## " heading { in_section = 1; next }
        in_section && /^## / { exit }
        in_section && $0 ~ ("^[[:space:]]*-[[:space:]]*" field ":[[:space:]]*") {
            sub("^[[:space:]]*-[[:space:]]*" field ":[[:space:]]*", "", $0)
            print
            exit
        }
    ' "$file" 2>/dev/null || true
}

legacy_plan_phase() {
    local file="$1"
    [ -f "$file" ] || return 0

    awk '
        /^## State$/ { in_state = 1; next }
        in_state && /^## / { exit }
        in_state && /^[[:space:]]*-[[:space:]]*Phase:[[:space:]]*/ {
            sub(/^[[:space:]]*-[[:space:]]*Phase:[[:space:]]*/, "", $0)
            print
            exit
        }
    ' "$file" 2>/dev/null || true
}

line_if_present() {
    local label="$1"
    local value="$2"
    [ -n "$value" ] || return 0
    CONTEXT="${CONTEXT}${label}: ${value}"$'\n'
}

[ -d "$SPINE_DIR" ] || exit 0

CONTEXT=""

if [ -f "$ACTIVE_FILE" ]; then
    SLUG="$(tr -d '[:space:]' < "$ACTIVE_FILE" 2>/dev/null || true)"
    if [ -n "$SLUG" ]; then
        CONTEXT="Project Spine resume"$'\n\n'
        PLAN_FILE="${SPINE_DIR}/features/${SLUG}/plan.md"
        SPEC_FILE="${SPINE_DIR}/features/${SLUG}/spec.md"
        PRIMARY_FILE=""
        SOURCE=""

        if [ -f "$PLAN_FILE" ]; then
            PRIMARY_FILE="$PLAN_FILE"
            SOURCE="plan"
        elif [ -f "$SPEC_FILE" ]; then
            PRIMARY_FILE="$SPEC_FILE"
            SOURCE="spec"
        fi

        PLAN_SOURCE="$(section_field "$PLAN_FILE" "Resume" "Source")"
        if [ "$PLAN_SOURCE" = "spec" ] && [ -f "$SPEC_FILE" ]; then
            PRIMARY_FILE="$SPEC_FILE"
            SOURCE="spec"
        fi

        CONTEXT="${CONTEXT}Active feature: ${SLUG}"$'\n'

        if [ -n "$PRIMARY_FILE" ]; then
            PHASE="$(section_field "$PRIMARY_FILE" "Resume" "Phase")"
            GATE="$(section_field "$PRIMARY_FILE" "Resume" "Gate")"
            CURRENT_SLICE="$(section_field "$PRIMARY_FILE" "Resume" "Current Slice")"
            NEXT_STEP="$(section_field "$PRIMARY_FILE" "Resume" "Next Step")"
            OPEN_QUESTIONS="$(section_field "$PRIMARY_FILE" "Resume" "Open Questions")"
            FILES_IN_PLAY="$(section_field "$PRIMARY_FILE" "Resume" "Files in Play")"
            VERIFICATION_GATE="$(section_field "$PRIMARY_FILE" "Resume" "Verification Gate")"

            if [ -z "$PHASE" ] && [ "$SOURCE" = "plan" ]; then
                PHASE="$(legacy_plan_phase "$PLAN_FILE")"
            fi
            if [ -z "$PHASE" ] && [ "$SOURCE" = "spec" ]; then
                PHASE="spec"
            fi
            if [ -z "$GATE" ]; then
                if [ "$SOURCE" = "plan" ]; then
                    GATE="$(section_field "$PLAN_FILE" "Review Gate" "Status")"
                else
                    GATE="pending"
                fi
            fi
            if [ -z "$VERIFICATION_GATE" ] && [ "$SOURCE" = "plan" ]; then
                VERIFICATION_GATE="$(section_field "$PLAN_FILE" "Verification Gate" "Status")"
            fi
            if [ -z "$CURRENT_SLICE" ] && [ "$SOURCE" = "spec" ]; then
                CURRENT_SLICE="review the active spec and decide if it is ready for planning"
            fi
            if [ -z "$NEXT_STEP" ] && [ "$SOURCE" = "spec" ]; then
                NEXT_STEP="approve the spec or run \$spine-pwf ${SLUG} when ready to plan"
            fi

            line_if_present "Source" "$SOURCE"
            line_if_present "Phase" "$PHASE"
            line_if_present "Gate" "$GATE"
            line_if_present "Verification gate" "$VERIFICATION_GATE"
            line_if_present "Primary file" "$PRIMARY_FILE"
            line_if_present "Current slice" "$CURRENT_SLICE"
            line_if_present "Next step" "$NEXT_STEP"
            line_if_present "Open questions" "$OPEN_QUESTIONS"
            line_if_present "Files in play" "$FILES_IN_PLAY"
        fi

        CONTEXT="${CONTEXT}"$'\n'

        BACKLOG_DIR="${SPINE_DIR}/features/backlog"
        if [ -f "$SPEC_FILE" ] && [ -d "$BACKLOG_DIR" ]; then
            BACKLOG_WARNINGS=""
            in_front=false
            in_deps=false
            while IFS= read -r line; do
                if [[ "$line" == "---" ]]; then
                    if [ "$in_front" = true ]; then
                        break
                    fi
                    in_front=true
                    continue
                fi
                if [ "$in_front" = true ] && [[ "$line" == "dependencies:"* ]]; then
                    in_deps=true
                    val="${line#*:}"
                    val="${val// /}"
                    if [ "$val" != "[]" ] && [ -n "$val" ] && [ -d "$BACKLOG_DIR/$val" ]; then
                        BACKLOG_WARNINGS="${BACKLOG_WARNINGS}  - ${val} (in backlog)"$'\n'
                    fi
                    continue
                fi
                if [ "$in_deps" = true ] && [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
                    dep="${BASH_REMATCH[1]}"
                    if [ -d "$BACKLOG_DIR/$dep" ]; then
                        BACKLOG_WARNINGS="${BACKLOG_WARNINGS}  - ${dep} (in backlog)"$'\n'
                    fi
                    continue
                fi
                if [ "$in_deps" = true ] && ! [[ "$line" =~ ^[[:space:]]+- ]]; then
                    in_deps=false
                fi
            done < "$SPEC_FILE"
            if [ -n "$BACKLOG_WARNINGS" ]; then
                CONTEXT="${CONTEXT}WARNING: Active feature has dependencies in backlog:"$'\n'"${BACKLOG_WARNINGS}"$'\n'
            fi
        fi
    fi
fi

emit_context "$CONTEXT"
