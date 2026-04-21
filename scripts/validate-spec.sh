#!/usr/bin/env bash
set -euo pipefail

SPEC="${1:-}"
if [ -z "$SPEC" ]; then
    echo "Usage: validate-spec.sh <spec.md>" >&2
    exit 1
fi

if [ ! -f "$SPEC" ]; then
    echo "Error: $SPEC not found" >&2
    exit 1
fi

errors=0

check_section() {
    local heading="$1"
    if ! grep -q "^## ${heading}" "$SPEC"; then
        echo "Missing section: ## ${heading}" >&2
        errors=$((errors + 1))
    fi
}

check_section "Problem"
check_section "Requirements"
check_section "Boundaries"
check_section "Inputs & Outputs"
check_section "Constraints"
check_section "Change type"
check_section "Acceptance Criteria"
check_section "Invariants"
check_section "Open Questions"
check_section "Resume"

if ! grep -qE '^\*\*Role:\*\*' "$SPEC"; then
    echo "Missing **Role:** line" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^- Type:' "$SPEC"; then
    echo "Missing change type entry" >&2
    errors=$((errors + 1))
fi

if ! awk '
    /^## Invariants$/ { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && /^[[:space:]]*-[[:space:]]+/ {
        line = $0
        sub(/^[[:space:]]*-[[:space:]]+/, "", line)
        if (line !~ /^Enforcement hint:/) {
            found = 1
            exit
        }
    }
    END { exit(found ? 0 : 1) }
' "$SPEC"; then
    echo "Invariants section missing invariant entry" >&2
    errors=$((errors + 1))
fi

if ! awk '
    /^## Invariants$/ { in_section = 1; next }
    in_section && /^## / { exit }
    in_section && /^[[:space:]]*-[[:space:]]+Enforcement hint:/ { found = 1; exit }
    END { exit(found ? 0 : 1) }
' "$SPEC"; then
    echo "NOTE: Spec has no Enforcement hint entries under Invariants" >&2
fi

if ! "$(dirname "$0")/validate-spine-doc.sh" "$SPEC" "spec"; then
    errors=$((errors + 1))
fi

if [ "$errors" -gt 0 ]; then
    echo "" >&2
    echo "Validation failed: ${errors} error(s)" >&2
    exit 1
fi

echo "Spec valid: ${SPEC}"
