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

check_v15_anchors() {
    local plan="$1"
    local refs slugs unresolved

    refs="$(grep -oE '\(#[a-z0-9_-]+\)' "$plan" | sed 's/^(#//; s/)$//' | sort -u || true)"
    slugs="$(awk '/^#### /{
        sub(/^#### /, "")
        line = tolower($0)
        gsub(/[`*~()\[\]{}.,:;!?"\047<>|+=&^%$#@]/, "", line)
        gsub(/[\\/]/, "", line)
        gsub(/[ \t]+/, "-", line)
        sub(/^-/, "", line)
        sub(/-$/, "", line)
        print line
    }' "$plan" | sort -u || true)"

    unresolved="$(comm -23 <(printf '%s\n' "$refs" | sed '/^$/d') <(printf '%s\n' "$slugs" | sed '/^$/d') || true)"
    if [ -n "$unresolved" ]; then
        echo "NOTE: unresolved anchor references in $plan:" >&2
        echo "$unresolved" | sed 's/^/  #/' >&2
    fi
}

# Only v15 plans are accepted. Older phase/v6 shapes must be rewritten.
if ! grep -qE '^## Chapters$' "$PLAN" || ! grep -qE '^## Implementation tracks$' "$PLAN"; then
    echo "Missing v15 sections: expected ## Chapters and ## Implementation tracks" >&2
    echo "Legacy phase-based and v6 flat plan formats are no longer supported" >&2
    exit 1
fi

# Required sections.
for section in "Overview" "Context" "Chapters" "Implementation tracks" \
               "Verification evidence" "Acceptance gate" \
               "Verification Gate" "Review Gate" "State" "Resume"; do
    if ! grep -qE "^## ${section}$" "$PLAN"; then
        echo "v15: Missing section: ## ${section}" >&2
        errors=$((errors + 1))
    fi
done

# Required header lines.
if ! grep -qE '^\*\*Strategy:\*\*' "$PLAN"; then
    echo "v15: Missing **Strategy:** line" >&2
    errors=$((errors + 1))
fi
if ! grep -qE '^\*\*Scope:\*\*' "$PLAN"; then
    echo "v15: Missing **Scope:** line" >&2
    errors=$((errors + 1))
fi

strategy="$(sed -n 's/^\*\*Strategy:\*\*[[:space:]]*//p' "$PLAN" | awk 'NR==1 {print $1}')"
case "$strategy" in
    CORRECTNESS|EQUIVALENCE|STRUCTURAL|REGRESSION|'{'STRATEGY'}'|CORRECTNESS\|*) ;;
    *)
        echo "v15: Invalid or missing strategy: '$strategy'" >&2
        errors=$((errors + 1))
        ;;
esac

if ! grep -q "TRUST BOUNDARY" "$PLAN"; then
    echo "v15: Missing TRUST BOUNDARY marker" >&2
    errors=$((errors + 1))
fi

chapter_count="$(grep -cE '^### Chapter [0-9]+' "$PLAN" 2>/dev/null || true)"
chapter_count="${chapter_count:-0}"
if [ "$chapter_count" -lt 1 ]; then
    echo "v15: Plan must have at least one ### Chapter N" >&2
    errors=$((errors + 1))
fi

awk '
    /^### Chapter [0-9]+/ { if (in_chapter) check_chapter(); in_chapter=1; name=$0; reset(); next }
    /^### / && in_chapter { check_chapter(); in_chapter=0; next }
    /^## / && in_chapter { check_chapter(); in_chapter=0; next }
    in_chapter && /^\*\*Why grouped:\*\*/ { if (!seen_what && !seen_dec && !seen_prov) why=1; else order=1 }
    in_chapter && /^\*\*What changes:\*\*/ { if (why && !seen_dec && !seen_prov) seen_what=1; else order=1 }
    in_chapter && /^\*\*Decisions:\*\*/ { if (why && seen_what && !seen_prov) seen_dec=1; else order=1 }
    in_chapter && /^\*\*Provisions:\*\*/ { if (why && seen_what) seen_prov=1; else order=1 }
    END { if (in_chapter) check_chapter(); exit(bad ? 1 : 0) }
    function reset() { why=0; seen_what=0; seen_dec=0; seen_prov=0; order=0 }
    function check_chapter() {
        if (!why || !seen_what || order) {
            print "v15: " name " missing/out-of-order Why grouped / What changes" > "/dev/stderr"
            bad=1
        }
        if (!seen_dec) print "NOTE: " name " has no Decisions block" > "/dev/stderr"
        if (!seen_prov) print "NOTE: " name " has no Provisions block" > "/dev/stderr"
    }
' "$PLAN" || errors=$((errors + 1))

track_count="$(grep -cE '^### Track [0-9]+' "$PLAN" 2>/dev/null || true)"
track_count="${track_count:-0}"
if [ "$track_count" -lt 1 ]; then
    echo "v15: Plan must have at least one ### Track N" >&2
    errors=$((errors + 1))
fi

awk '
    /^#### (Modify|Append to|Replace in) / && $0 !~ / lines / {
        print "v15: code heading missing file/line location: " $0 > "/dev/stderr"
        bad = 1
    }
    /^### Track [0-9]+/ { if (in_track) check_track(); in_track = 1; track_name = $0; reset(); next }
    /^### / && in_track { check_track(); reset(); in_track = 0 }
    /^## /  && in_track { check_track(); reset(); in_track = 0 }
    in_track && /^\*\*Constraints:\*\*/  { has_constraints = 1 }
    in_track && /^\*\*Code:\*\*/         { has_code = 1 }
    in_track && /^\*\*Tests:\*\*/        { has_tests = 1 }
    in_track && /^\*\*Verify:\*\*/       { has_verify = 1 }
    in_track && /^\*\*Green when:\*\*/   { has_green = 1 }
    END { if (in_track) check_track(); exit(bad ? 1 : 0) }
    function reset() { has_constraints = 0; has_code = 0; has_tests = 0; has_verify = 0; has_green = 0 }
    function check_track( missing) {
        missing = ""
        if (!has_constraints) missing = missing "Constraints "
        if (!has_code)        missing = missing "Code "
        if (!has_tests)       missing = missing "Tests "
        if (!has_verify)      missing = missing "Verify "
        if (!has_green)       missing = missing "Green-when "
        if (missing != "") {
            print "v15: " track_name " missing: " missing > "/dev/stderr"
            bad = 1
        }
    }
' "$PLAN" || errors=$((errors + 1))

check_v15_anchors "$PLAN"

if ! awk '/^## Verification Gate$/{f=1;next} /^## /{f=0} f && /Status:/{ok=1} END{exit(ok?0:1)}' "$PLAN"; then
    echo "v15: Verification Gate missing Status field" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^### Agent self-review' "$PLAN"; then
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

echo "Plan valid (v15): ${PLAN}"
