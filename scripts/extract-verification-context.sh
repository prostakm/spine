#!/usr/bin/env bash
set -euo pipefail

PLAN="${1:-}"
if [ -z "$PLAN" ]; then
    echo "Usage: extract-verification-context.sh <plan.md>" >&2
    exit 1
fi

if [ ! -f "$PLAN" ]; then
    echo "Error: $PLAN not found" >&2
    exit 1
fi

section_body() {
    local file="$1"
    local heading="$2"

    awk -v heading="$heading" '
        $0 == "## " heading { in_section = 1; next }
        in_section && /^## / { exit }
        in_section { print }
    ' "$file"
}

subsection_body() {
    local file="$1"
    local parent="$2"
    local heading="$3"

    awk -v parent="$parent" -v heading="$heading" '
        $0 == "## " parent { in_parent = 1; next }
        in_parent && /^## / { exit }
        in_parent && $0 == "### " heading { in_sub = 1; next }
        in_sub && /^### / { exit }
        in_sub { print }
    ' "$file"
}

emit_block() {
    local title="$1"
    local body="$2"

    body="$(printf '%s\n' "$body" | sed '/^[[:space:]]*$/d')"
    [ -n "$body" ] || return 0
    printf '## %s\n%s\n\n' "$title" "$body"
}

strategy="$(sed -n 's/^\*\*Strategy:\*\*[[:space:]]*//p' "$PLAN" | awk 'NR==1 {print $1}')"
feature="$(sed -n 's/^# Feature:[[:space:]]*//p' "$PLAN" | awk 'NR==1 {print}')"

case "$strategy" in
    CORRECTNESS)
        primary_one_title="Rules"
        primary_one_body="$(subsection_body "$PLAN" "Spec + proof" "Rules")"
        primary_two_title="Properties"
        primary_two_body="$(subsection_body "$PLAN" "Spec + proof" "Properties")"
        ;;
    EQUIVALENCE)
        primary_one_title="Equivalence anchor"
        primary_one_body="$(subsection_body "$PLAN" "Spec + proof" "Equivalence anchor")"
        primary_two_title="Properties"
        primary_two_body="$(subsection_body "$PLAN" "Spec + proof" "Properties")"
        ;;
    STRUCTURAL)
        primary_one_title="Architecture constraints"
        primary_one_body="$(subsection_body "$PLAN" "Spec + proof" "Architecture constraints")"
        primary_two_title="Properties"
        primary_two_body="$(subsection_body "$PLAN" "Spec + proof" "Properties")"
        ;;
    REGRESSION)
        primary_one_title="New invariant"
        primary_one_body="$(subsection_body "$PLAN" "Spec + proof" "New invariant")"
        primary_two_title="Properties"
        primary_two_body="$(subsection_body "$PLAN" "Spec + proof" "Properties")"
        ;;
    *)
        echo "Error: unsupported or missing strategy '$strategy'" >&2
        exit 1
        ;;
esac

verification_packet="$(subsection_body "$PLAN" "Agent instructions" "Verification evidence")"

printf '# Verification Context\n\n'
printf -- '- Feature: %s\n' "${feature:-unknown}"
printf -- '- Source: %s\n' "$PLAN"
printf -- '- Strategy: %s\n\n' "$strategy"

printf 'This packet intentionally excludes implementation strategy and other '\
'below-trust-boundary context.\n\n'

emit_block "$primary_one_title" "$primary_one_body"
emit_block "$primary_two_title" "$primary_two_body"
emit_block "Verification evidence" "$verification_packet"
