#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
EXTRACTOR="$REPO_ROOT/scripts/extract-verification-context.sh"
TMP_DIR="$REPO_ROOT/.tmp-extract-verification-tests"

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

cleanup() { rm -rf "$TMP_DIR"; }
trap cleanup EXIT
cleanup
mkdir -p "$TMP_DIR"

run_case "new_format_extracts_behaviors_and_packet" \
    bash -c '
      "'$EXTRACTOR'" "'$REPO_ROOT'/docs/EXAMPLE-PLAN.md" > "'$TMP_DIR'/new.out"
      grep -q "^- Strategy: STRUCTURAL" "'$TMP_DIR'/new.out"
      grep -q "^## Behaviors" "'$TMP_DIR'/new.out"
      grep -q "^## Acceptance matrix" "'$TMP_DIR'/new.out"
      grep -q "^## Verifier packet" "'$TMP_DIR'/new.out"
      ! grep -q "^### Implementation" "'$TMP_DIR'/new.out"
      ! grep -q "^### File manifest" "'$TMP_DIR'/new.out"
    '

run_case "template_placeholder_strategy_supported" \
    bash -c '
      "'$EXTRACTOR'" "'$REPO_ROOT'/templates/.spine/features/_template/plan.md" > "'$TMP_DIR'/template.out"
      grep -q "^- Strategy: strategy" "'$TMP_DIR'/template.out"
      grep -q "^## Behaviors" "'$TMP_DIR'/template.out"
    '

run_case "legacy_chapters_extracts_review_zone" \
    bash -c '
      "'$EXTRACTOR'" "'$REPO_ROOT'/docs/EXAMPLE-PLAN-LEGACY.md" > "'$TMP_DIR'/legacy.out"
      grep -q "^- Strategy: CORRECTNESS" "'$TMP_DIR'/legacy.out"
      grep -q "^## Chapters" "'$TMP_DIR'/legacy.out"
      grep -q "^## Verification evidence" "'$TMP_DIR'/legacy.out"
      ! grep -q "TRUST BOUNDARY" "'$TMP_DIR'/legacy.out"
    '

run_case "missing_strategy_fails" \
    bash -c '
      cp "'$REPO_ROOT'/templates/.spine/features/_template/plan.md" "'$TMP_DIR'/missing-strategy.md"
      python3 - "'$TMP_DIR'/missing-strategy.md" <<"PY"
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
s = s.replace("- **Strategy:** {CORRECTNESS|EQUIVALENCE|STRUCTURAL|REGRESSION}", "- **NoStrategy:** nope")
s = s.replace("- Strategy: `{strategy}`", "- NoStrategy: `{strategy}`")
p.write_text(s)
PY
      "'$EXTRACTOR'" "'$TMP_DIR'/missing-strategy.md" 2>&1 | grep -q "missing strategy"
    '

echo ""
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
