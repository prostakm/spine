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
is_template=0

if [[ "$PLAN" == *"/_template/plan.md"* ]] || grep -qF '{FEATURE_NAME}' "$PLAN"; then
    is_template=1
fi

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

section_has_field() {
    local heading="$1"
    local field="$2"

    awk -v heading="$heading" -v field="$field" '
        $0 == "## " heading { in_section = 1; next }
        in_section && /^## / { exit }
        in_section && $0 ~ ("^[[:space:]]*-[[:space:]]*" field ":[[:space:]]*") { found = 1; exit }
        END { exit(found ? 0 : 1) }
    ' "$PLAN"
}

section_has_field_value() {
    local heading="$1"
    local field="$2"
    local pattern="$3"

    awk -v heading="$heading" -v field="$field" -v pattern="$pattern" '
        $0 == "## " heading { in_section = 1; next }
        in_section && /^## / { exit }
        in_section && $0 ~ ("^[[:space:]]*-[[:space:]]*" field ":[[:space:]]*") {
            value = $0
            sub("^[[:space:]]*-[[:space:]]*" field ":[[:space:]]*", "", value)
            if (value ~ pattern) found = 1
            exit
        }
        END { exit(found ? 0 : 1) }
    ' "$PLAN"
}

check_section "Context"
check_section "Resume"
check_section "Decisions"
check_section "Spec + proof"
check_section "Agent instructions"
check_section "Verification Gate"
check_section "Review Gate"
check_section "State"

if ! grep -qE '^\*\*Scope:\*\*' "$PLAN"; then
    echo "Missing **Scope:** line" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^## Changed Surface$' "$PLAN" && \
   ! grep -qE '^## Changed code surface$' "$PLAN" && \
   ! grep -qE '^> \[!NOTE\] Changed Surface' "$PLAN"; then
    echo "NOTE: Missing changed-surface overview (prefer ## Changed Surface)" >&2
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

if ! grep -qE '^### Verification evidence' "$PLAN"; then
    echo "Missing ### Verification evidence in Agent instructions" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^#### Verifier packet' "$PLAN"; then
    echo "Missing #### Verifier packet in Verification evidence" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^#### Test evidence to collect' "$PLAN"; then
    echo "Missing #### Test evidence to collect in Verification evidence" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^### Properties' "$PLAN"; then
    echo "Missing ### Properties subsection in Spec + proof" >&2
    errors=$((errors + 1))
fi

properties_count="$(grep -cE '^### Properties$' "$PLAN" 2>/dev/null || true)"
properties_count="${properties_count:-0}"
if [ "$is_template" -eq 0 ] && [ "$properties_count" -ne 1 ]; then
    echo "Plan must contain exactly one active ### Properties block (found ${properties_count})" >&2
    errors=$((errors + 1))
fi

if grep -qE '^### Properties' "$PLAN" && ! grep -qE '<!-- AUTHOR:' "$PLAN"; then
    echo "Properties section missing AUTHOR marker (human | human-validated | agent-proposed)" >&2
    errors=$((errors + 1))
fi

if grep -qE '^### Properties' "$PLAN"; then
    if ! awk '
        /^### Properties$/ { in_props = 1; next }
        in_props && /^### / { exit }
        in_props && /^## / { exit }
        in_props && (/^> \[!.*\*\*P[0-9]+/ || /^[[:space:]]*-[[:space:]]*\*\*P[0-9]+\*\*/) {
            found = 1
            exit
        }
        END { exit(found ? 0 : 1) }
    ' "$PLAN"; then
        echo "Properties section missing property IDs (e.g. > [!NOTE] **P1** or - **P1**)" >&2
        errors=$((errors + 1))
    fi

    if ! awk '
        /^### Properties$/ { in_props = 1; next }
        in_props && /^### / { exit }
        in_props && /^## / { exit }
        in_props && /Invariant:/ { found = 1; exit }
        END { exit(found ? 0 : 1) }
    ' "$PLAN"; then
        echo "Properties section missing Invariant label" >&2
        errors=$((errors + 1))
    fi

    if ! awk '
        /^### Properties$/ { in_props = 1; next }
        in_props && /^### / { exit }
        in_props && /^## / { exit }
        in_props && /Evidence:/ { found = 1; exit }
        END { exit(found ? 0 : 1) }
    ' "$PLAN"; then
        echo "Properties section missing Evidence label" >&2
        errors=$((errors + 1))
    fi
fi

if ! section_has_field_value "Verification Gate" "Status" '^(pending|passed|failed)$'; then
    echo "Verification Gate missing Status field" >&2
    errors=$((errors + 1))
fi

if ! section_has_field "Verification Gate" "Last run"; then
    echo "Verification Gate missing Last run field" >&2
    errors=$((errors + 1))
fi

if ! section_has_field "Verification Gate" "Verdict"; then
    echo "Verification Gate missing Verdict field" >&2
    errors=$((errors + 1))
fi

if ! section_has_field "Verification Gate" "Blocking issues"; then
    echo "Verification Gate missing Blocking issues field" >&2
    errors=$((errors + 1))
fi

if ! section_has_field "Resume" "Verification Gate"; then
    echo "Resume missing Verification Gate field" >&2
    errors=$((errors + 1))
fi

if ! section_has_field "State" "Verification Gate"; then
    echo "State missing Verification Gate field" >&2
    errors=$((errors + 1))
fi

require_heading() {
    local heading="$1"
    local message="$2"
    if ! grep -qE "^### ${heading}$" "$PLAN"; then
        echo "$message" >&2
        errors=$((errors + 1))
    fi
}

forbid_heading() {
    local heading="$1"
    local message="$2"
    if grep -qE "^### ${heading}$" "$PLAN"; then
        echo "$message" >&2
        errors=$((errors + 1))
    fi
}

if [ "$is_template" -eq 0 ]; then
    case "$strategy" in
        CORRECTNESS)
            require_heading "Rules" "CORRECTNESS plans must include ### Rules"
            forbid_heading "Equivalence anchor" "CORRECTNESS plans must delete unused ### Equivalence anchor block"
            forbid_heading "Architecture constraints" "CORRECTNESS plans must delete unused ### Architecture constraints block"
            forbid_heading "Reproduction" "CORRECTNESS plans must delete unused ### Reproduction block"
            ;;
        EQUIVALENCE)
            require_heading "Equivalence anchor" "EQUIVALENCE plans must include ### Equivalence anchor"
            forbid_heading "Rules" "EQUIVALENCE plans must delete unused ### Rules block"
            forbid_heading "Architecture constraints" "EQUIVALENCE plans must delete unused ### Architecture constraints block"
            forbid_heading "Reproduction" "EQUIVALENCE plans must delete unused ### Reproduction block"
            ;;
        STRUCTURAL)
            require_heading "Architecture constraints" "STRUCTURAL plans must include ### Architecture constraints"
            require_heading "Boundary behavior" "STRUCTURAL plans must include ### Boundary behavior"
            require_heading "Smoke tests" "STRUCTURAL plans must include ### Smoke tests"
            forbid_heading "Rules" "STRUCTURAL plans must delete unused ### Rules block"
            forbid_heading "Equivalence anchor" "STRUCTURAL plans must delete unused ### Equivalence anchor block"
            forbid_heading "Reproduction" "STRUCTURAL plans must delete unused ### Reproduction block"
            ;;
        REGRESSION)
            require_heading "Reproduction" "REGRESSION plans must include ### Reproduction"
            require_heading "Blast radius" "REGRESSION plans must include ### Blast radius"
            require_heading "New invariant" "REGRESSION plans must include ### New invariant"
            forbid_heading "Rules" "REGRESSION plans must delete unused ### Rules block"
            forbid_heading "Equivalence anchor" "REGRESSION plans must delete unused ### Equivalence anchor block"
            forbid_heading "Architecture constraints" "REGRESSION plans must delete unused ### Architecture constraints block"
            ;;
    esac
fi

# New-format-only checks (skip for legacy)
if ! grep -qE '^### Phase [0-9]' "$PLAN"; then

    # Trust boundary marker
    if ! grep -q "TRUST BOUNDARY" "$PLAN"; then
        echo "Missing trust boundary marker" >&2
        errors=$((errors + 1))
    fi

    # Max 7 decisions
    decision_count="$(grep -cE '^### (D|[🔴🟡🟢][[:space:]]+D)[0-9]+' "$PLAN" 2>/dev/null || true)"
    decision_count="${decision_count:-0}"
    if [ "$decision_count" -gt 7 ]; then
        echo "Too many decisions (${decision_count}) — split the feature" >&2
        errors=$((errors + 1))
    fi

    # Agent self-review section (warning, not error — filled post-impl)
    if ! grep -qE '^### Agent self-review' "$PLAN"; then
        echo "NOTE: Missing ### Agent self-review section" >&2
    fi

    # Neotree-style file tree (warning, not error)
    if ! grep -qE '^[▾●]' "$PLAN" && ! grep -qE '^### File tree' "$PLAN"; then
        echo "NOTE: No neotree-style file tree found. Consider using ### File tree with ▾/● markers." >&2
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
