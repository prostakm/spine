#!/usr/bin/env bash
# Project Spine: SessionStart hook
# Loads project and active feature context at startup/resume.

SPINE_DIR=".spine"
ACTIVE_FILE="${SPINE_DIR}/active-feature"

[ ! -d "$SPINE_DIR" ] && exit 0

echo "Project Spine context:"

for file in "${SPINE_DIR}/project.md" "${SPINE_DIR}/conventions.md" "${SPINE_DIR}/progress.md"; do
    if [ -f "$file" ]; then
        echo
        echo "--- ${file} ---"
        sed -n '1,40p' "$file"
    fi
done

if [ -f "$ACTIVE_FILE" ]; then
    SLUG=$(cat "$ACTIVE_FILE" 2>/dev/null | tr -d '[:space:]')
    if [ -n "$SLUG" ]; then
        for file in \
            "${SPINE_DIR}/features/${SLUG}/spec.md" \
            "${SPINE_DIR}/features/${SLUG}/plan.md" \
            "${SPINE_DIR}/features/${SLUG}/findings.md" \
            "${SPINE_DIR}/features/${SLUG}/log.md"
        do
            if [ -f "$file" ]; then
                echo
                echo "--- ${file} ---"
                sed -n '1,40p' "$file"
            fi
        done
    fi
fi
