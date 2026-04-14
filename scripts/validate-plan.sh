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

# Detect legacy phase-based format — skip new-format checks entirely
if grep -qE '^### Phase [0-9]' "$PLAN"; then
    # Legacy format — minimal checks only
    if ! grep -qE '^## Review Gate' "$PLAN"; then
        echo "Missing section: ## Review Gate" >&2
        errors=$((errors + 1))
    fi
    if [ "$errors" -gt 0 ]; then
        echo "" >&2
        echo "Validation failed: ${errors} error(s)" >&2
        exit 1
    fi
    echo "Plan valid (legacy format): ${PLAN}"
    exit 0
fi

check_section() {
    local heading="$1"
    if ! grep -q "^## ${heading}" "$PLAN"; then
        echo "Missing section: ## ${heading}" >&2
        errors=$((errors + 1))
    fi
}

check_section "Context"
check_section "Resume"
check_section "Decisions"
check_section "Spec + proof"
check_section "Agent instructions"
check_section "Review Gate"
check_section "State"

if ! grep -qE '^\*\*Scope:\*\*' "$PLAN"; then
    echo "Missing **Scope:** line" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^\*\*Strategy:\*\*' "$PLAN"; then
    echo "Missing **Strategy:** line" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^\*\*Goal:\*\*' "$PLAN"; then
    echo "Missing **Goal:** line" >&2
    errors=$((errors + 1))
fi

strategy="$(sed -n 's/^\*\*Strategy:\*\*[[:space:]]*//p' "$PLAN" | awk 'NR==1 {print $1}')"
case "$strategy" in
    CORRECTNESS|EQUIVALENCE|STRUCTURAL|REGRESSION) ;;
    *)
        echo "Invalid or missing strategy: '$strategy' (must be CORRECTNESS|EQUIVALENCE|STRUCTURAL|REGRESSION)" >&2
        errors=$((errors + 1))
        ;;
esac

if ! grep -qE '^### Acceptance gate' "$PLAN"; then
    echo "Missing ### Acceptance gate in Agent instructions" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^### Properties' "$PLAN"; then
    echo "Missing ### Properties subsection in Spec + proof" >&2
    errors=$((errors + 1))
fi

if grep -qE '^### Properties' "$PLAN" && ! grep -qE '<!-- AUTHOR:' "$PLAN"; then
    echo "Properties section missing AUTHOR marker (human | human-validated | agent-proposed)" >&2
    errors=$((errors + 1))
fi

if [ "$errors" -gt 0 ]; then
    echo "" >&2
    echo "Validation failed: ${errors} error(s)" >&2
    exit 1
fi

echo "Plan valid: ${PLAN}"
