#!/usr/bin/env bash
set -euo pipefail

PLAN="${1:-}"
if [ -z "$PLAN" ]; then
    echo "Usage: validate-plan.sh <plan.md>" >&2
    exit 1
fi

if [ ! -f "$PLAN" ]; then
    echo "Error: $PLAN not found" >&2
    exit 1
fi

errors=0

check_section() {
    local heading="$1"
    if ! grep -q "^## ${heading}" "$PLAN"; then
        echo "Missing section: ## ${heading}" >&2
        errors=$((errors + 1))
    fi
}

check_section "Context"
check_section "Review Gate"
check_section "State"

if ! grep -qE '^\*\*Goal:\*\*' "$PLAN"; then
    echo "Missing **Goal:** line" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^\*\*Approach:\*\*' "$PLAN"; then
    echo "Missing **Approach:** line" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '### Phase [0-9]' "$PLAN"; then
    echo "No phases defined (need at least ### Phase 1)" >&2
    errors=$((errors + 1))
fi

phase=1
while grep -q "### Phase ${phase}" "$PLAN"; do
    if ! grep -A500 "### Phase ${phase}" "$PLAN" | grep -qE '^\*\*Verify:\*\*'; then
        echo "Phase ${phase}: missing **Verify:** command" >&2
        errors=$((errors + 1))
    fi
    if ! grep -A500 "### Phase ${phase}" "$PLAN" | grep -qE '^\*\*Status:\*\*'; then
        echo "Phase ${phase}: missing **Status:** field" >&2
        errors=$((errors + 1))
    fi
    phase=$((phase + 1))
done

if [ "$errors" -gt 0 ]; then
    echo "" >&2
    echo "Validation failed: ${errors} error(s)" >&2
    exit 1
fi

echo "Plan valid: ${PLAN}"
