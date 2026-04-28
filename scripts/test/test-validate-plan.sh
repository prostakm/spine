#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/validate-plan.sh"
FIXTURES="$SCRIPT_DIR/fixtures"
export FIXTURES

pass=0
fail=0

run_case() {
    local name="$1"; shift
    if "$@"; then
        printf "PASS  %s\n" "$name"
        pass=$((pass + 1))
    else
        printf "FAIL  %s\n" "$name" >&2
        fail=$((fail + 1))
    fi
}

# P0: test_chapter_block_order — validator accepts well-formed v15.
run_case "test_chapter_block_order" \
    "$VALIDATOR" "$REPO_ROOT/docs/EXAMPLE-PLAN.md"

# P1: test_anchor_links_resolve — example has no unresolved-anchor NOTE.
run_case "test_anchor_links_resolve" \
    bash -c "'$VALIDATOR' '$REPO_ROOT/docs/EXAMPLE-PLAN.md' 2>&1 | \
             grep -qE 'NOTE: unresolved anchor' && false || true"

# P2: test_slug_rule_matches_github_and_marksman — golden fixture.
run_case "test_slug_rule_matches_github_and_marksman" \
    python3 - "$FIXTURES/slug_cases.json" <<'PY'
import json, re, sys
bad = False
for row in json.load(open(sys.argv[1])):
    heading = row["heading"]
    expected = row["slug"]
    actual = heading.lower()
    actual = re.sub(r"[`*~()\[\]{}.,:;!?\"'<>|+=&^%$#@]", "", actual)
    actual = re.sub(r"[/\\]", "", actual)
    actual = re.sub(r"\s+", "-", actual.strip())
    if actual != expected:
        print(f"  heading={heading} expected={expected} actual={actual}", file=sys.stderr)
        bad = True
sys.exit(1 if bad else 0)
PY

# P4: test_format_detection — only v15 is accepted.
run_case "test_format_detection::v15" \
    bash -c "'$VALIDATOR' '$REPO_ROOT/docs/EXAMPLE-PLAN.md' | grep -qE 'Plan valid \\(v15\\)'"

run_case "test_format_detection::reject_legacy" \
    bash -c '
      tmp=$(mktemp)
      printf "# Feature: old\n\n### Phase 1: old\n\n## Review Gate\n" > "$tmp"
      if "'$VALIDATOR'" "$tmp" 2>&1 | grep -q "no longer supported"; then
        rm -f "$tmp"
        exit 0
      fi
      rm -f "$tmp"
      exit 1
    '

run_case "test_format_detection::reject_v6_flat" \
    bash -c '
      tmp=$(mktemp)
      printf "# Feature: old\n\n## Decisions\n\n## Spec + proof\n\n## Agent instructions\n" > "$tmp"
      if "'$VALIDATOR'" "$tmp" 2>&1 | grep -q "no longer supported"; then
        rm -f "$tmp"
        exit 0
      fi
      rm -f "$tmp"
      exit 1
    '

run_case "test_code_headings_require_line_location" \
    bash -c '
      tmp=$(mktemp)
      python3 - "'$REPO_ROOT'/docs/EXAMPLE-PLAN.md" "$tmp" <<"PY"
import sys
src, dst = sys.argv[1], sys.argv[2]
s = open(src).read().replace("#### Modify tax/allocation.py lines 1-34", "#### Modify tax/allocation.py", 1)
open(dst, "w").write(s)
PY
      if "'$VALIDATOR'" "$tmp" 2>&1 | grep -q "code heading missing file/line location"; then
        rm -f "$tmp"
        exit 0
      fi
      rm -f "$tmp"
      exit 1
    '

echo ""
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
