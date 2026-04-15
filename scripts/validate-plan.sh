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

if ! grep -qE '^(\*\*Goal:\*\*|- Goal:)' "$PLAN"; then
    echo "Missing Goal line" >&2
    errors=$((errors + 1))
fi

strategy="$(sed -n 's/^\*\*Strategy:\*\*[[:space:]]*//p' "$PLAN" | awk 'NR==1 {print $1}')"
case "$strategy" in
    CORRECTNESS|EQUIVALENCE|STRUCTURAL|REGRESSION) ;;
    *)
        echo "Invalid or missing strategy: '$strategy'" >&2
        echo "Must be CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION" >&2
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

# New-format-only checks (skip for legacy)
if ! grep -qE '^### Phase [0-9]' "$PLAN"; then

    # Budget field (warning, not error)
    if ! grep -qE '^\*\*Budget:\*\*' "$PLAN"; then
        echo "NOTE: Missing **Budget:** line" >&2
    fi

    # Trust boundary marker
    if ! grep -q "TRUST BOUNDARY" "$PLAN"; then
        echo "Missing trust boundary marker" >&2
        errors=$((errors + 1))
    fi

    # Triage markers on decisions (warning, not error)
    if ! grep -qE '^### [🔴🟡🟢]' "$PLAN" 2>/dev/null; then
        echo "NOTE: No triage markers on decisions" >&2
    fi

    # Max 7 triage-marked decisions
    triage_count="$(grep -cE '^### [🔴🟡🟢]' "$PLAN" 2>/dev/null || true)"
    triage_count="${triage_count:-0}"
    if [ "$triage_count" -gt 7 ]; then
        echo "Too many triage-marked decisions (${triage_count}) — split the feature" >&2
        errors=$((errors + 1))
    fi

    # Agent self-review section (warning, not error — filled post-impl)
    if ! grep -qE '^### Agent self-review' "$PLAN"; then
        echo "NOTE: Missing ### Agent self-review section" >&2
    fi

fi

if ! "$(dirname "$0")/validate-spine-doc.sh" "$PLAN" "plan"; then
    errors=$((errors + 1))
fi

if [ "$errors" -gt 0 ]; then
    echo "" >&2
    echo "Validation failed: ${errors} error(s)" >&2
    exit 1
fi

echo "Plan valid: ${PLAN}"
