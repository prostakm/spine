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
        in_section && /TRUST BOUNDARY/ { exit }
        in_section && /^## / { exit }
        in_section { print }
    ' "$file"
}

body_until_trust_boundary() {
    local file="$1"
    local heading="$2"

    awk -v heading="$heading" '
        $0 == "## " heading { in_section = 1; print; next }
        in_section && /TRUST BOUNDARY/ { exit }
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

extract_strategy() {
    local file="$1"
    awk '
        /^[[:space:]]*-[[:space:]]*\*\*Strategy:\*\*/ {
            sub(/^[[:space:]]*-[[:space:]]*\*\*Strategy:\*\*[[:space:]]*/, "", $0)
            gsub(/[`{}]/, "", $0)
            print $1
            exit
        }
        /^\*\*Strategy:\*\*/ {
            sub(/^\*\*Strategy:\*\*[[:space:]]*/, "", $0)
            gsub(/[`{}]/, "", $0)
            print $1
            exit
        }
        /^- Strategy:[[:space:]]*/ {
            sub(/^- Strategy:[[:space:]]*/, "", $0)
            gsub(/[`{}]/, "", $0)
            print $1
            exit
        }
    ' "$file"
}

feature="$(sed -n 's/^# Feature:[[:space:]]*//p' "$PLAN" | awk 'NR==1 {print}')"
strategy="$(extract_strategy "$PLAN")"

if [ -z "$strategy" ]; then
    echo "Error: missing strategy in $PLAN" >&2
    exit 1
fi

is_new_format=0
is_legacy_format=0
if grep -q '^## Behaviors' "$PLAN"; then
    is_new_format=1
elif grep -q '^## Spec + proof' "$PLAN" || grep -q '^## Chapters$' "$PLAN"; then
    is_legacy_format=1
fi

printf '# Verification Context\n\n'
printf -- '- Feature: %s\n' "${feature:-unknown}"
printf -- '- Source: %s\n' "$PLAN"
printf -- '- Strategy: %s\n\n' "$strategy"

printf 'This packet intentionally excludes implementation strategy, findings, log, '\
'and other below-trust-boundary context except the explicit verifier packet.\n\n'

if [ "$is_new_format" = "1" ]; then
    proof_body="$(body_until_trust_boundary "$PLAN" "Behaviors")"
    if [ -n "$(printf '%s\n' "$proof_body" | sed '/^[[:space:]]*$/d')" ]; then
        printf '%s\n\n' "$proof_body"
    fi
    emit_block "Verifier packet" "$(subsection_body "$PLAN" "Agent instructions" "Verification packet")"
    emit_block "Verification evidence" "$(subsection_body "$PLAN" "Agent instructions" "Verification evidence")"
    exit 0
fi

if [ "$is_legacy_format" != "1" ]; then
    echo "Error: unknown plan format in $PLAN" >&2
    exit 1
fi

if grep -q '^## Chapters$' "$PLAN"; then
    proof_body="$(body_until_trust_boundary "$PLAN" "Chapters")"
    if [ -n "$(printf '%s\n' "$proof_body" | sed '/^[[:space:]]*$/d')" ]; then
        printf '%s\n\n' "$proof_body"
    fi
    emit_block "Verification evidence" "$(section_body "$PLAN" "Verification evidence")"
    exit 0
fi

case "$strategy" in
    CORRECTNESS)
        emit_block "Rules" "$(subsection_body "$PLAN" "Spec + proof" "Rules")"
        emit_block "Properties" "$(subsection_body "$PLAN" "Spec + proof" "Properties")"
        ;;
    EQUIVALENCE)
        emit_block "Equivalence anchor" "$(subsection_body "$PLAN" "Spec + proof" "Equivalence anchor")"
        emit_block "Properties" "$(subsection_body "$PLAN" "Spec + proof" "Properties")"
        ;;
    STRUCTURAL)
        emit_block "Architecture constraints" "$(subsection_body "$PLAN" "Spec + proof" "Architecture constraints")"
        emit_block "Properties" "$(subsection_body "$PLAN" "Spec + proof" "Properties")"
        ;;
    REGRESSION)
        emit_block "New invariant" "$(subsection_body "$PLAN" "Spec + proof" "New invariant")"
        emit_block "Properties" "$(subsection_body "$PLAN" "Spec + proof" "Properties")"
        ;;
    *)
        echo "Error: unsupported strategy '$strategy'" >&2
        exit 1
        ;;
esac

emit_block "Verifier packet" "$(subsection_body "$PLAN" "Agent instructions" "Verification packet")"
emit_block "Verification evidence" "$(subsection_body "$PLAN" "Agent instructions" "Verification evidence")"
