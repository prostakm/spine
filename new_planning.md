> Historical note: this was the design memo for the planning overhaul.
> The source of truth is now the implemented skills, templates, validators,
> and examples in this repo.

Here's the modification guide. I'll work through each file that needs to
change, what changes, and why - organized by the order you'd actually do the
work.

---

## 1. The template — `templates/.spine/features/_template/plan.md`

This is the foundation. Everything else references it. Replace the current
template entirely.

**What changes:** The current template mixes review-relevant content
(Goal, Approach, Alternatives) with agent instructions
(phases with file paths and pseudocode) in a flat structure. The new template
separates these into two zones with a trust boundary.

**What's preserved:** The Context section pointing to project files, the Review
Gate, the Decisions table, and the `> [R]:` inline review protocol all carry
over unchanged - they already work well.

```markdown
# Feature: {FEATURE_NAME}

## Context
- Project: `.spine/project.md`
- Conventions: `.spine/conventions.md`
- Progress: `.spine/progress.md`
- Spec: `.spine/features/{slug}/spec.md` (if present)

**Status:** DRAFT | REVIEW | ANNOTATED | APPROVED
**Scope:** {one sentence — what changes, for whom}
**Risk:** LOW | MEDIUM | HIGH — {one phrase justifying}
**Strategy:** CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION

---

## Decisions

**Goal:** {what this delivers — one sentence}

**Approach:** {technical strategy — 1-2 sentences}

**Rejected options (only if informative):**
- {alt} — {reason}

**Key risks (only if non-obvious):**
- {risk} → {mitigation}

### D1: {decision title}

**Chosen:** {what}
**Over:** {alt} — {why not}
**Consequence:** {what this locks in}

> ANNOTATION:

<!-- Repeat D2, D3... Max 7. If more, split the feature. -->

---

## Spec + proof

<!-- Delete the blocks that don't match your strategy. -->

<!-- ──── CORRECTNESS ──────────────────────────────────── -->

### Rules

**R1: {rule}** — {plain English}

```text
{fixture input} -> {expected}
{fixture input} -> {expected}
```

### Properties (Hypothesis)

- **P1:** {invariant}
- **P2:** {invariant}

### Snapshot anchors

- {output worth locking}

### Edge cases

- {specific scenario}

<!-- ──── EQUIVALENCE ──────────────────────────────────── -->

### Equivalence anchor

**What must not change:** {be specific}
**Granularity:** exact | tolerance | structural
**Capture:** snapshot before, assert after

### Existing suite

**All tests in** {scope} **pass unmodified.**
If any assertion changes → escalate.

### Delta (perf only)

- {measurable improvement}

<!-- ──── STRUCTURAL ───────────────────────────────────── -->

### Architecture constraints

- {import rule, permission check, migration constraint}

### Boundary behavior

- `{request}` -> `{status + shape}`
- `{request}` -> `{status}`
- `{request}` -> `{status}`

### Smoke tests

- {wiring proof}

<!-- ──── REGRESSION ───────────────────────────────────── -->

### Reproduction

**Test:** {assertion}
**Expected:** {correct}
**Actual:** {buggy}

### Blast radius

**Scope:** {what else breaks}
**Verify:** {what suite to run}

### New invariant

- {property this bug reveals}

---

## Contracts

<!-- Skip for EQUIVALENCE and REGRESSION unless interfaces change. -->

### Inputs

```
{types — dataclass, TypedDict, or plain signature}
```

### Outputs

```
{types}
```

### Side effects

- {DB write, event, external call}

---

<!-- ═══════════════════════════════════════════════════════ -->
<!-- TRUST BOUNDARY — reviewer stops here                   -->
<!-- ═══════════════════════════════════════════════════════ -->

## Agent instructions

### File manifest

- `CREATE path/to/file`
  - symbols: `{new symbol}`, `{new symbol}`
  - change: {what this file will contain}
- `MODIFY path/to/file`
  - symbols: `{existing symbol}`, `{new helper}`
  - change: {what changes in this file}

### Implementation strategy

<!-- Reference decisions by number. Phase if needed, flat if not. -->

1. `{path or symbol}` - {step referencing D1}

   ```text
   {code snippet or pseudocode for the non-trivial part}
   ```

2. `{path or symbol}` - {step referencing D2}

   ```text
   {code snippet or pseudocode for the non-trivial part}
   ```

### Test implementation notes

- {parametrize, hypothesis hints, snapshot format}

### Acceptance gate

- [ ] {strategy-specific checks}

---

## Decisions log
- {date} - {decision} - {rationale}

## Errors
- {error} - attempt: {attempt} - resolution: {resolution}

<!-- REVIEW: PENDING — add > [R]: comments inline, mark > [R]: APPROVED when done -->

## Review Gate
- Status: pending

## State
- Phase: planning
```

Key structural differences from the old template:
Goal/Approach/Alternatives move inside the Decisions section rather than
floating at the top - they're the first decision. The old generic phase
structure (Phase 1, Phase 2... each with Verify/Status) is replaced by the
flat Agent Instructions section with an Acceptance Gate. Phases within Agent
Instructions are still possible ("phase if needed, flat if not") but they're
now below the trust boundary, which means the reviewer doesn't need to read
them.

---

## 2. The skill — `.agents/skills/spine-pwf/SKILL.md`

**What changes:** The "Plan Creation" section needs to reflect the new
template structure and the strategy selector. The detail requirements shift
from "file paths + function signatures + pseudocode for everything" to
"file paths + signatures in Agent Instructions, but decisions + proof sketch +
contracts above the trust boundary."

Replace the `### Detail requirements` block:

```markdown
### Detail requirements

The plan has two zones separated by a trust boundary:

**Above the trust boundary (human reviews):**
- **Strategy selector**: CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION
  Pick based on the nature of the change. Only CORRECTNESS requires
  new domain knowledge from the reviewer.
- **Decisions**: only forks that need human judgment or lock in behavior.
  Start with one-line `Goal` and `Approach`. Format: Chosen / Over /
  Consequence. Max 7 — split if more.
- **Spec + proof**: strategy-adaptive section. Include ONLY the block
  matching the chosen strategy, delete the rest:
  - CORRECTNESS: rules as explicit condition -> expectation cases;
    one-line fixtures for simple cases, compact structured blocks for
    complex conditionals; Hypothesis properties,
    snapshot anchors, edge cases
  - EQUIVALENCE: equivalence anchor (what must not change), existing
    suite requirement, delta metric (perf only)
  - STRUCTURAL: architecture constraints (import rules, permission checks),
    boundary behavior as explicit request/context -> expected outcomes,
    smoke tests
  - REGRESSION: reproduction test (expected vs actual), blast radius,
    new invariant if warranted
- **Contracts**: input/output types crossing boundaries. Skip for
  EQUIVALENCE and REGRESSION unless interfaces change.

**Below the trust boundary (agent executes, proofs verify):**
- **File manifest**: exact paths with create/modify/delete, touched
  symbols, and what changes in each file
- **Implementation strategy**: steps referencing decisions by number.
  Phase if natural stages exist, flat if not. For every non-trivial
  step, include a code snippet or pseudocode sketch.
- **Test implementation notes**: exact test targets, parametrize hints,
  Hypothesis strategies, snapshot format
- **Acceptance gate**: strategy-specific checklist and concrete validation
  commands when known

The reviewer reads top-to-bottom and stops at the trust boundary.
Everything below is verified by the proof sketch, not by eyeballs.
```

Replace the `### Style` block — add one line:

```markdown
### Style
- Bullet points over paragraphs
- Short statements, not sentences
- Code blocks for schemas/signatures/logic
- No tables in active plans. Encode conditionals directly in bullets or
  compact structured blocks.
- Delete unused strategy blocks from spec+proof — don't leave empty sections
```

In the `## Plan Review (Gate 2)` section, update the prompt message:

```markdown
> "Plan at `.spine/features/{slug}/plan.md`. 
> Review sections 1-4 (above the trust boundary). 
> Add `> [R]:` comments next to anything you want changed.
> Mark `> [R]: APPROVED` when ready."
```

In `## Implementation (after Gate 2)`, add a note about strategy-driven execution:

```markdown
### Strategy-driven implementation
- CORRECTNESS: write tests from section 3 fixtures/properties FIRST,
  then implement until tests pass
- EQUIVALENCE: capture equivalence anchor BEFORE any changes,
  then refactor, then assert anchor matches
- STRUCTURAL: implement architecture constraints as linter rules
  or structural tests FIRST, then wire the plumbing
- REGRESSION: write the reproduction test FIRST (must fail on
  current code), then fix, then verify blast radius
```

---

## 3. The example — `docs/EXAMPLE-PLAN.md`

The current example (auth-session) is implementation-heavy with Go code in
every phase. Replace with two short examples demonstrating different
strategies. Keep the existing one as `docs/EXAMPLE-PLAN-LEGACY.md` for
reference during transition.

Create a new `docs/EXAMPLE-PLAN.md` with a CORRECTNESS example
(compact, payroll-like) and a STRUCTURAL example (new endpoint). I'd keep each
under 80 lines - the old example was 120+ lines of Go code that a reviewer
would have to parse. The new ones should be readable in under 3 minutes.

The CORRECTNESS example should show: a few decisions, a rules table with
fixture data, 3-4 Hypothesis properties, and a compact agent instructions
section. The auth-session example you already have is actually closer to
STRUCTURAL - it adds endpoints, middleware, and storage without complex domain
logic. Re-framing it with the new template would be instructive.

---

## 4. The validator — `scripts/validate-plan.sh`

Update section checks to match the new template structure:

```bash
# Replace the current checks with:
check_section "Decisions"    # was implicitly in Goal/Approach
check_section "Spec + proof"
check_section "Agent instructions"
check_section "Review Gate"
check_section "State"

# Replace Goal/Approach checks:
if ! grep -qE '^\*\*Strategy:\*\*' "$PLAN"; then
    echo "Missing **Strategy:** line" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^\*\*Scope:\*\*' "$PLAN"; then
    echo "Missing **Scope:** line" >&2
    errors=$((errors + 1))
fi

if ! grep -qE '^\*\*Goal:\*\*' "$PLAN"; then
    echo "Missing **Goal:** line" >&2
    errors=$((errors + 1))
fi

# Validate strategy value
STRATEGY=$(grep -oP '^\*\*Strategy:\*\*\s*\K\S+' "$PLAN" 2>/dev/null || true)
case "$STRATEGY" in
    CORRECTNESS|EQUIVALENCE|STRUCTURAL|REGRESSION) ;;
    *)
        echo "Invalid or missing strategy: '$STRATEGY' (must be CORRECTNESS|EQUIVALENCE|STRUCTURAL|REGRESSION)" >&2
        errors=$((errors + 1))
        ;;
esac

# Check that acceptance gate exists
if ! grep -qE '### Acceptance gate' "$PLAN"; then
    echo "Missing ### Acceptance gate in Agent instructions" >&2
    errors=$((errors + 1))
fi

# Remove the old phase-counting logic (### Phase N with Verify/Status).
# The new template doesn't require phases — agent instructions can be flat.
```

---

## 5. The spec template — `templates/.spine/features/_template/spec.md`

The spec template feeds into the plan. Two small additions make the handoff
smoother - they give the planner enough signal to pick a strategy and
pre-populate the proof sketch.

Add after `## Constraints`:

```markdown
## Change type
<!-- Helps the planner pick the right proof strategy. -->
- Type: {new-logic | refactor | new-endpoint | bugfix | performance | infrastructure}
```

Add to `## Acceptance Criteria`:

```markdown
## Acceptance Criteria
- [ ] {testable criterion}

## Invariants
<!-- Properties that must ALWAYS hold. Carried into plan's proof sketch. -->
- {e.g., "tax is never negative"}
```

This is a lightweight addition - two fields, both optional. But when they're
filled in during `$spine-spec`, the planner doesn't have to invent the proof
strategy or hunt for invariants. The spec skill's elicitation flow already asks
about acceptance criteria; it just needs to also ask
"what must always be true?" for the invariants field.

---

## 6. The spec skill — `.agents/skills/spine-spec/SKILL.md`

In Step 3 (Elicit requirements), add invariants to both role personas:

Under **Architect** concerns:

```markdown
- Invariants: what must always be true? (e.g., "no circular imports", 
  "response time < 200ms", "migration is reversible")
```

Under **Product Owner** concerns:

```markdown
- Invariants: what business rules are absolute? (e.g., "tax never 
  negative", "user can always access their own data", "no data loss 
  on cancellation")
```

Under **Both roles always ask**, add:

```markdown
- What type of change is this? (new logic, refactor, new endpoint, 
  bugfix, performance, infrastructure)
```

---

## 7. The brainstorm skill — `.agents/skills/spine-brainstorm/SKILL.md`

Minimal change. In Step 5 (Write the spec), add a note:

```markdown
- Include `## Change type` and `## Invariants` sections to help the
  planner select proof strategy
```

---

## 8. The AGENTS.md / CLAUDE.md templates

Update `### Plan detail` in `templates/AGENTS.md`:

```markdown
### Plan detail
Plans have two zones separated by a trust boundary:
- **Above** (reviewer reads): decisions, spec+proof (strategy-adaptive), contracts
- **Below** (agent executes): file manifest, implementation steps, test notes, acceptance gate
- Strategy selector: CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION
- Only CORRECTNESS requires domain knowledge to review — all others verify preservation
- Reviewer reads top-to-bottom and stops at the trust boundary
- `> [R]:` annotations go in sections above the trust boundary
- See `docs/EXAMPLE-PLAN.md` for style
```

In `templates/CLAUDE.md`, update the plan creation steps (section "Starting a feature"):

```markdown
6. Draft `plan.md` with strategy-adaptive structure:
   - Pick **Strategy** based on change type from spec
   - Write **Decisions** (Chosen/Over/Consequence)
   - Write **Spec + proof** using the matching strategy block
   - Write **Contracts** (skip for EQUIVALENCE/REGRESSION)
   - Write **Agent instructions** below the trust boundary
7. Run `.spine/scripts/validate-plan.sh .spine/features/{slug}/plan.md`
```

---

## 9. What NOT to change

**The hooks stay as-is.** `session-start.sh`, `stop.sh`, and
`opencode-spine.js` read plan.md for status and phase markers. The new
template keeps `## Review Gate` and `## State` in the same format, so hooks
don't break.

**The `> [R]:` review protocol stays as-is.** It already works well. The new
template just focuses where annotations land - above the trust boundary.

**The `config.yaml` autonomy levels stay as-is.** The strategy selector is
orthogonal to autonomy. Low/med/high controls how much the planner asks before
committing; the strategy controls what the plan contains.

Feature cleanup and backlog scripts stay as-is. They operate on directories and
slugs, not plan content.

---

## 10. Migration path

For existing features with plans in the old format, don't retrofit. The old
format still works - it just doesn't get the review efficiency gains. New
features use the new template automatically.

To test the new template before committing: create a feature with
`$spine-pwf`, check that `validate-plan.sh` passes, check that `stop.sh` still
reads the status correctly, and check that session recovery
(`session-start.sh`) still picks up the active feature context.

The one risk: if the validate script's old checks are in CI and you update the
script before updating existing in-flight plans, those plans will fail
validation. Update the script to accept both old and new formats during
transition - check for either `### Phase 1` OR `### Acceptance gate`.
