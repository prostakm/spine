#!/usr/bin/env bash
# Project Spine: PreToolUse hook
# Reads the active feature's plan.md and injects first 30 lines into context.
# Runs before Write, Edit, Bash, Read, Glob, Grep operations.

SPINE_DIR=".spine"
ACTIVE_FILE="${SPINE_DIR}/active-feature"

if [ -f "$ACTIVE_FILE" ]; then
    SLUG=$(cat "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$SLUG" ]; then
        PLAN="${SPINE_DIR}/features/${SLUG}/plan.md"
        if [ -f "$PLAN" ]; then
            head -30 "$PLAN" 2>/dev/null
        fi
    fi
fi
