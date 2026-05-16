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

# Common checks: apply to legacy and new formats.
if ! grep -q "TRUST BOUNDARY" "$PLAN"; then
    echo "Missing TRUST BOUNDARY marker" >&2
    errors=$((errors + 1))
fi

for section in "Verification Gate" "Review Gate" "State" "Resume"; do
    if ! grep -qE "^## ${section}$" "$PLAN"; then
        echo "Missing hook section: ## ${section}" >&2
        errors=$((errors + 1))
    fi
done

if ! awk '/^## Verification Gate$/{f=1;next} /^## /{f=0} f && /Status:/{ok=1} END{exit(ok?0:1)}' "$PLAN"; then
    echo "Verification Gate missing Status field" >&2
    errors=$((errors + 1))
fi

# Max 7 decisions keeps review load bounded. Count unique D IDs.
decision_count=$(grep -oE '\*\*D[0-9]+\*\*|\*\*D[0-9]+:' "$PLAN" | sed -E 's/[^D0-9]//g' | sort -u | wc -l || echo 0)
decision_count="${decision_count:-0}"
if [ "$decision_count" -gt 7 ]; then
    echo "Too many decisions (${decision_count}); split or demote non-decisions" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '\[[MCD]\]' "$PLAN"; then
    echo "NOTE: No file tree [M]/[C]/[D] markers found" >&2
fi

# Format detection.
is_new_format=0
is_legacy_format=0
if grep -q '^## Behaviors' "$PLAN"; then
    is_new_format=1
elif grep -q '^## Spec + proof' "$PLAN" || grep -q '^## Chapters$' "$PLAN"; then
    is_legacy_format=1
fi

if [ "$is_new_format" = "0" ] && [ "$is_legacy_format" = "0" ]; then
    echo "Unknown plan format: expected ## Behaviors (new) or ## Chapters / ## Spec + proof (legacy)" >&2
    errors=$((errors + 1))
fi

if [ "$is_new_format" = "1" ]; then
    for section in "Status" "System view" "Behaviors" "Acceptance matrix" "Agent instructions"; do
        if ! grep -qE "^## ${section}$" "$PLAN"; then
            echo "New format: missing section ## ${section}" >&2
            errors=$((errors + 1))
        fi
    done

    if ! grep -qE '^- \*\*Strategy:\*\* (CORRECTNESS|EQUIVALENCE|STRUCTURAL|REGRESSION|\{)' "$PLAN"; then
        echo "New format: missing or invalid strategy line" >&2
        errors=$((errors + 1))
    fi

    # R7 (HARD): anchor reference resolution.
    refs=$(grep -oE '\[I[0-9]+\]\(#i[0-9]+\)' "$PLAN" | grep -oE '#i[0-9]+' | sort -u || true)
    for ref in $refs; do
        anchor_id="${ref#\#}"
        if ! grep -q "<a id=\"${anchor_id}\"" "$PLAN"; then
            echo "Broken anchor reference: ${ref} has no matching <a id=\"${anchor_id}\">" >&2
            errors=$((errors + 1))
        fi
    done

    # R8 (HARD): no <details> below trust boundary.
    boundary_line=$(grep -n 'TRUST BOUNDARY' "$PLAN" | head -1 | cut -d: -f1 || true)
    if [ -n "$boundary_line" ]; then
        if tail -n +"$boundary_line" "$PLAN" | grep -q '<details>'; then
            echo "Found <details> below trust boundary — agent zone must stay flat" >&2
            errors=$((errors + 1))
        fi
    fi

    # Soft: at least one flow step.
    if ! grep -qE '^### [A-Z]\.[0-9]' "$PLAN"; then
        echo "NOTE: New-format plan has no flow steps (### A.1, ### B.1, …)" >&2
    fi

    # Soft: flow count ≤ 3.
    flow_count=$(grep -oE '^### [A-Z]\.[0-9]' "$PLAN" | grep -oE '^### [A-Z]' | sort -u | wc -l || echo 0)
    flow_count="${flow_count:-0}"
    if [ "$flow_count" -gt 3 ]; then
        echo "NOTE: ${flow_count} flows — consider splitting the feature" >&2
    fi

    # Soft: decision summary should start with chose:.
    if grep -qE '^> \[!.*\] \*\*D[0-9]+' "$PLAN" || grep -qE '^- .*\*\*D[0-9]+\*\*' "$PLAN"; then
        if ! grep -qE '<summary>chose:' "$PLAN"; then
            echo "NOTE: Decisions found but no <summary>chose: …</summary> — check voice convention" >&2
        fi
    fi
else
    # Legacy plans run common checks only. Keep old unresolved-anchor helper as warning.
    refs="$(grep -oE '\(#[a-z0-9_-]+\)' "$PLAN" | sed 's/^(#//; s/)$//' | sort -u || true)"
    slugs="$(awk '/^#### /{
        sub(/^#### /, "")
        line = tolower($0)
        gsub(/[`*~()\[\]{}.,:;!?"\047<>|+=&^%$#@]/, "", line)
        gsub(/[\\/]/, "", line)
        gsub(/[ \t]+/, "-", line)
        sub(/^-/, "", line)
        sub(/-$/, "", line)
        print line
    }' "$PLAN" | sort -u || true)"
    unresolved="$(comm -23 <(printf '%s\n' "$refs" | sed '/^$/d') <(printf '%s\n' "$slugs" | sed '/^$/d') || true)"
    if [ -n "$unresolved" ]; then
        echo "NOTE: unresolved legacy anchor references in $PLAN:" >&2
        echo "$unresolved" | sed 's/^/  #/' >&2
    fi
fi

if ! grep -qE '^### Agent self-review|^### Agent self-review \(fill after implementation\)' "$PLAN"; then
    echo "NOTE: Missing ### Agent self-review section" >&2
fi

if ! "$(dirname "$0")/validate-spine-doc.sh" "$PLAN" "plan"; then
    errors=$((errors + 1))
fi

if [ "$errors" -gt 0 ]; then
    echo "" >&2
    echo "Validation failed: ${errors} error(s)" >&2
    exit 1
fi

if [ "$is_new_format" = "1" ]; then
    echo "Plan valid (flow-aligned): ${PLAN}"
else
    echo "Plan valid (legacy): ${PLAN}"
fi
