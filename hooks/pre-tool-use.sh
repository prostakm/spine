#!/usr/bin/env bash
# Project Spine: PreToolUse hook
# Blocks write/edit/bash tools when the plan review gate is pending.
# Only allows edits to plan.md and spec.md files while the gate is open.

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

block_with() {
    local reason="$1"
    printf '{"decision":"block","reason":"%s"}\n' "$(json_escape "$reason")"
    exit 0
}

plan_approved() {
    grep -qE '^R>\s*APPROVED' "$1" 2>/dev/null && return 0
    awk '/^## Review Gate$/{f=1;next} /^## /{f=0} f && /Status:[[:space:]]*approved/{found=1} END{exit(found?0:1)}' "$1" 2>/dev/null && return 0
    return 1
}

# ── Read active feature ──
[ -f "$ACTIVE_FILE" ] || exit 0

SLUG="$(tr -d '[:space:]' < "$ACTIVE_FILE" 2>/dev/null || true)"
[ -n "$SLUG" ] || exit 0

PLAN="${SPINE_DIR}/features/${SLUG}/plan.md"
SPEC="${SPINE_DIR}/features/${SLUG}/spec.md"

[ -f "$PLAN" ] || exit 0

plan_approved "$PLAN" && exit 0

# ── Plan review gate is pending. Determine tool and targets. ──

# Codex convention: CODEX_TOOL_NAME, CODEX_TOOL_INPUT
# Claude convention: stdin JSON with tool_name and tool_input
TOOL_NAME="${CODEX_TOOL_NAME:-}"
TOOL_INPUT="${CODEX_TOOL_INPUT:-}"

if [ -z "$TOOL_NAME" ]; then
    # Try Claude-style stdin JSON
    INPUT="$(cat 2>/dev/null || true)"
    if [ -n "$INPUT" ]; then
        TOOL_NAME="$(echo "$INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('tool_name',''))" 2>/dev/null || true)"
        TOOL_INPUT="$(echo "$INPUT" | python3 -c "import json,sys; print(json.dumps(json.load(sys.stdin).get('tool_input',{})))" 2>/dev/null || true)"
    fi
fi

# If we still can't determine the tool, allow (don't block uncertain)
TOOL_NAME_LOWER="$(echo "${TOOL_NAME:-}" | tr '[:upper:]' '[:lower:]')"
case "$TOOL_NAME_LOWER" in
    ""|read|grep|glob|ls|search|list|view) exit 0 ;;
esac

# ── Determine target paths ──
# For write/edit tools, extract file_path from args
TARGET_PATHS=""

if [ -n "$TOOL_INPUT" ]; then
    # Try to extract file_path (single) or paths (array) from JSON
    TARGET_PATHS="$(echo "$TOOL_INPUT" | python3 -c "
import json, sys
try:
    d = json.load(sys.stdin)
    paths = []
    if isinstance(d, dict):
        for key in ('file_path', 'path', 'filePath', 'file'):
            if key in d:
                paths.append(d[key])
        for key in ('file_paths', 'paths', 'edits'):
            val = d.get(key)
            if isinstance(val, list):
                for item in val:
                    if isinstance(item, dict):
                        for fk in ('file_path', 'path', 'oldPath', 'newPath', 'target'):
                            if fk in item:
                                paths.append(item[fk])
                    elif isinstance(item, str):
                        paths.append(item)
    for p in paths:
        if p: print(p)
except: pass
" 2>/dev/null || true)"
fi

# ── Check if all targets are plan.md or spec.md ──
SPINE_PLAN_ABS="$(realpath "$PLAN" 2>/dev/null || true)"
SPINE_SPEC_ABS="$(realpath "$SPEC" 2>/dev/null || true)"

ALL_SPINE=true
HAS_TARGETS=false

if [ -n "$TARGET_PATHS" ]; then
    while IFS= read -r tp; do
        [ -z "$tp" ] && continue
        HAS_TARGETS=true
        TA="$(realpath "$tp" 2>/dev/null || true)"
        if [ "$TA" != "$SPINE_PLAN_ABS" ] && [ "$TA" != "$SPINE_SPEC_ABS" ]; then
            ALL_SPINE=false
        fi
    done <<< "$TARGET_PATHS"
fi

# If specific targets exist and all are spine files, allow
if [ "$HAS_TARGETS" = true ] && [ "$ALL_SPINE" = true ]; then
    exit 0
fi

# If tool is write/edit and no targets parsed, block (safe default)
# Bash commands: allow read-only; block others when gate pending
if [ "$TOOL_NAME_LOWER" = "bash" ]; then
    # Allow if command starts with known read-only prefix
    CMD="$(echo "$TOOL_INPUT" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('command',''))" 2>/dev/null || true)"
    CMD="${CMD:-}"
    CMD_STRIPPED="${CMD#"${CMD%%[![:space:]]*}"}"
    case "$CMD_STRIPPED" in
        cat\ *|sed\ *|grep\ *|rg\ *|find\ *|ls\ *|head\ *|tail\ *|wc\ *|awk\ *|cut\ *|sort\ *|uniq\ *|tr\ *|stat\ *|\
        git\ status*|git\ diff*|git\ show*|git\ rev-parse*|git\ branch*|git\ log*|git\ blame*|\
        echo\ *)
            exit 0 ;;
    esac
    # Allow validation scripts
    case "$CMD_STRIPPED" in
        bash\ */.spine/scripts/validate-plan.sh*|\
        bash\ */.spine/scripts/validate-spec.sh*|\
        .spine/scripts/validate-plan.sh*|\
        .spine/scripts/validate-spec.sh*)
            exit 0 ;;
    esac
fi

block_with "Project Spine plan review gate is pending for '${SLUG}'. Plan at .spine/features/${SLUG}/plan.md is not approved. Review the plan, add R> comments, or mark R> APPROVED. The PreToolUse hook blocks writes to non-.spine files until the plan review gate passes."
