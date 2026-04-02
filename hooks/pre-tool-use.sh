#!/usr/bin/env bash
# Project Spine: PreToolUse hook
# Reminds Bash actions to check the active feature plan.
# In current Codex, PreToolUse hooks are most useful for Bash commands.

SPINE_DIR=".spine"
ACTIVE_FILE="${SPINE_DIR}/active-feature"

message="No active Project Spine feature."

if [ -f "$ACTIVE_FILE" ]; then
    SLUG=$(cat "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$SLUG" ]; then
        PLAN="${SPINE_DIR}/features/${SLUG}/plan.md"
        if [ -f "$PLAN" ]; then
            message="Active Project Spine plan: ${PLAN}. Review the current phase before running Bash."
        fi
    fi
fi

printf '{"systemMessage":"%s"}\n' "$message"
