#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR="$REPO_ROOT/scripts/validate-plan.sh"
TMP_DIR="$REPO_ROOT/.tmp-validate-plan-tests"

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

run_case "new_format_example_valid" \
    bash -c "'$VALIDATOR' '$REPO_ROOT/docs/EXAMPLE-PLAN.md' | grep -qE 'Plan valid \\(flow-aligned\\)'"

run_case "template_valid" \
    bash -c "'$VALIDATOR' '$REPO_ROOT/templates/.spine/features/_template/plan.md' | grep -qE 'Plan valid \\(flow-aligned\\)'"

run_case "legacy_example_valid" \
    bash -c "'$VALIDATOR' '$REPO_ROOT/docs/EXAMPLE-PLAN-LEGACY.md' | grep -qE 'Plan valid \\(legacy\\)'"

run_case "broken_i_anchor_hard_fails" \
    bash -c '
      cp "'$REPO_ROOT'/templates/.spine/features/_template/plan.md" "'$TMP_DIR'/bad-anchor.md"
      printf "\nBad ref [I99](#i99)\n" >> "'$TMP_DIR'/bad-anchor.md"
      "'$VALIDATOR'" "'$TMP_DIR'/bad-anchor.md" 2>&1 | grep -q "Broken anchor reference: #i99"
    '

run_case "details_below_boundary_hard_fails" \
    bash -c '
      cp "'$REPO_ROOT'/templates/.spine/features/_template/plan.md" "'$TMP_DIR'/bad-details.md"
      printf "\n<details><summary>bad</summary>\n\n- bad\n</details>\n" >> "'$TMP_DIR'/bad-details.md"
      "'$VALIDATOR'" "'$TMP_DIR'/bad-details.md" 2>&1 | grep -q "Found <details> below trust boundary"
    '

run_case "four_flows_warns_but_passes" \
    bash -c '
      cp "'$REPO_ROOT'/templates/.spine/features/_template/plan.md" "'$TMP_DIR'/four-flows.md"
      python3 - "'$TMP_DIR'/four-flows.md" <<"PY"
from pathlib import Path
import sys
p = Path(sys.argv[1])
s = p.read_text()
s = s.replace("## Acceptance matrix", "## Flow C — extra\n\n### C.1 — extra\n\n- → impl: [I1](#i1)\n\n## Flow D — extra\n\n### D.1 — extra\n\n- → impl: [I1](#i1)\n\n## Acceptance matrix")
p.write_text(s)
PY
      "'$VALIDATOR'" "'$TMP_DIR'/four-flows.md" >"'$TMP_DIR'/four-flows.out" 2>&1
      grep -q "NOTE: 4 flows" "'$TMP_DIR'/four-flows.out"
    '

echo ""
echo "passed: $pass  failed: $fail"
[ "$fail" -eq 0 ]
