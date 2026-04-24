# Feature: {FEATURE_NAME}

<!-- Human context only. Keep prose hard-wrapped at 100 chars.
     Bold only the smallest crucial fragment.
     Above the trust boundary, optimize for reviewer speed:
     changed code surface first, then compact context, then the chosen
     approach and proof.
     Keep implementation details (component names, pixel specs, library
     choices) out of Context — those go in the agent zone Implementation
     strategy.
     Spec-derived fields carry forward approved spec facts for plan
     self-sufficiency. Reviewer skims for accuracy, does not re-approve.
     Criticality tags map to callout boxes (use sparingly):
       > [!CAUTION]   volatile: data loss, money errors, corruption, silent wrong results
       > [!WARNING]   UX-critical: directly affects what users see or experience
       > [!IMPORTANT] locks in: constrains future architecture or behavior
       > [!TIP]       default / no tag
     Most decisions get no tag and render as a plain heading.
     -->

## Changed Surface

Keep this as a compact review map. Prefer a fenced `text` tree with short
reasons over prose bullets or callout walls.

```text
app/
├── feature/
│   └── module.py                      [M] why this file matters to review
└── tests/
    └── test_module.py                 [C] proof for D1 / P1
```

## Context

<!-- Keep this to 4-6 bullets. Carry approved spec facts forward, but do not
     restate the whole spec. When the before/after shape matters, add one
     small ascii schematic instead of a paragraph. -->

- Spec: `.spine/features/{slug}/spec.md` (approved)
- Goal: {user-facing outcome in one line}
- Gap: {what is wrong or outdated now}
- In: {what changes in this slice}
- Out: {what stays unchanged or deferred}
- Constraints: {hard limits, unsupported data, arch boundary, etc.}
- Risk driver: {only if the reviewer needs one more fact to judge risk}

### Current -> target (optional)

```text
today: {request-time joins / Python aggregation / controller branching / etc.}
after: {materialized views / typed mapping / static rule / etc.}
```

**Status:** DRAFT | REVIEW | ANNOTATED | APPROVED
**Scope:** {from spec — what changes, for whom}
**Risk:** LOW | MEDIUM | HIGH - {one phrase justifying}
<!-- Derived from spec Change type -->
**Strategy:** CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION

---

## Decisions

- Goal: {what this delivers — distilled from spec Problem}
- Approach: {technical strategy - 1-2 short lines}
- Risk: {risk} -> {mitigation}

<!-- Include only real forks. Constraints/conventions are not decisions unless
     a competing option was considered. Prefer Chose/Over/Consequence.
     Criticality tags are optional. Use a callout only when the tag adds signal.
     -->

### D1: {decision title}

- Chose: {what}
- Over: {alt} - {why not}
- Consequence: {what this commits to}

> ANNOTATION:

<!-- For tagged decisions, replace the heading with a callout:

     > [!CAUTION] D1: {title}
     > - **Chose:** {what}
     > - **Over:** {alt} — {why not}
     > - **Consequence:** {what this commits to}

     Use > [!WARNING] for UX-critical, > [!IMPORTANT] for locks-in.
     Most decisions stay as plain ### headings. -->

<!-- Repeat D2, D3... Max 7. If more, split the feature. -->

---

## Spec + proof

<!-- Delete the blocks that do not match your strategy. -->

<!-- CORRECTNESS -->

### Rules

<!-- Prefer plain acceptance cases. Use compact yaml only when multiple
     interacting fields would make bullets too lossy. -->

**R1: {rule}** - {plain English}

- When {condition}, {observable}
- When {condition}, {observable}

```yaml
case: {only when bullets are too lossy}
when:
  {field}: {value}
then:
  {observable}: {expected}
```

### Properties
<!-- AUTHOR: human | human-validated | agent-proposed
     Triage by review importance. Use callouts only for the few properties
     that actually drive risk. Lower-priority properties can be plain bullets.
     Enforcement mode is a tag on the header, not a separate field.
     Invariant + Evidence only. No "Why" field. -->

> [!CAUTION] **P1** — `runtime` — `human`
> **Invariant:** range: {what must hold}
> **Evidence:** {rule/script/test/manual check that proves it}

- **P2** — `static` — `agent-proposed`
  Invariant: structural: {what must hold}
  Evidence: {rule/script/test/manual check that proves it}

### Snapshot anchors

- {output worth locking}

### Edge cases

- {specific scenario} {⚠️ if catastrophic}

### Code sketch (optional)

```python
def {name}({args}) -> {returnType}:
    # ...obvious setup...
    {decisionCarryingLine}  # D1
    # ...obvious wiring...
```

### Arch boundaries schematic (optional)

Use when the change touches multiple layers. Shows locked vs changed
boundaries — lets the reviewer verify no arch violations at a glance:

```text
Layer A ─── (unchanged, D1 locks)
  │
  ▼
Layer B ──── condition?
  ├── path1 ──→ Layer C ← NEW
  └── path2 ──→ Layer D ← UNCHANGED (P2)
```

### Control flow tree (optional)

Use for branching logic with >2 paths. Shows decision outcomes,
not variable names or code:

```text
query loads
  ├── pending ──→ LoadingState
  ├── error    ──→ StateCard
  └── ok:
       ├── condition=false ──→ path A
       └── condition=true:
            ├── sub-pending ──→ LoadingState
            ├── sub-error   ──→ StateCard
            └── sub-ok      ──→ path B (unchanged)
```

<!-- EQUIVALENCE -->

### Equivalence anchor

- What must not change: {be specific}
- Granularity: exact | tolerance | structural
- Capture: snapshot before, assert after

### Existing suite

- **All tests in** {scope} **pass unmodified.**
- If any assertion changes -> escalate.

### Properties
<!-- Use callouts only for highest-risk properties. Lower-priority properties
     can be plain bullets with the same `Invariant` / `Evidence` fields. -->

> [!NOTE] **P1** — `runtime` — `human`
> **Invariant:** preservation: {identical before and after}
> **Evidence:** {rule/script/test/manual check that proves it}

- **P2** — `runtime` — `agent-proposed`
  Invariant: stability: {what remains deterministic or idempotent}
  Evidence: {rule/script/test/manual check that proves it}

### Delta (perf only)

- {measurable improvement}

<!-- STRUCTURAL -->

### Architecture constraints

- {import rule, permission check, migration constraint}

### Boundary behavior

```text
{METHOD} {path}:
  {condition} -> {status + shape}
  {condition} -> {status}
```

### Flow diagram (optional)

Use for request chains, selector pipelines, or branching control flow:

```text
{source} -> {guard or transform}
{condition}:
  ├── yes -> {path A}
  └── no  -> {path B}
```

See CORRECTNESS block for arch boundaries schematic and control flow
tree notation — same diagrams apply when structural changes touch
multiple layers or have branching paths.

### Smoke tests

- {wiring proof}

### Properties
<!-- Use callouts only for highest-risk properties. Lower-priority properties
     can be plain bullets with the same `Invariant` / `Evidence` fields. -->

> [!NOTE] **P1** — `static` — `human`
> **Invariant:** structural: {architecture invariant}
> **Evidence:** {rule/script/test/manual check that proves it}

- **P2** — `runtime` — `agent-proposed`
  Invariant: preservation: {boundary behavior that must stay true}
  Evidence: {rule/script/test/manual check that proves it}

<!-- REGRESSION -->

### Reproduction

- Test: {assertion}
- Expected: {correct}
- Actual: {buggy}

### Blast radius

- Scope: {what else breaks}
- Verify: {what suite to run}

### New invariant

- {property this bug reveals}

### Properties
<!-- Use callouts only for highest-risk properties. Lower-priority properties
     can be plain bullets with the same `Invariant` / `Evidence` fields. -->

> [!CAUTION] **P1** — `runtime` — `human`
> **Invariant:** {category}: {the violated invariant, now a property}
> **Evidence:** {rule/script/test/manual check that proves it}

- **P2** — `runtime` — `agent-proposed`
  Invariant: regression: {secondary behavior that must remain fixed}
  Evidence: {rule/script/test/manual check that proves it}

## Contracts

<!-- Skip when spec I/O already has complete types and no enrichment
     is needed. Include when planning discovers actual signatures,
     query shapes, or types the spec left abstract.
     Always include Data flow and Side effects when they exist. -->

### Data flow

```typescript
{source} -> {transform} -> {destination}
```

### Inputs

```typescript
{name}: {type}  # constraint
```

### Outputs

```typescript
{name}: {type}  # constraint
```

### Side effects

- ⚠ {DB write, event, external call}

---

<!-- TRUST BOUNDARY - reviewer stops here -->

## Agent instructions

<!-- All fenced code blocks in this section MUST use a language tag
     that matches the code content (python, typescript, rust, bash, yaml).
     Use text ONLY for plain diagrams (trees, flowcharts). -->

### Verification evidence

This section defines the bounded packet for the context-minimized verifier.

#### Verifier packet

- Strategy: `{CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION}`
- Properties: `{P-refs from the active strategy block above}`
- Rules / invariants to extract:
  `{R-refs | architecture constraints | equivalence anchor | new invariant}`
- Verifier constraints: fresh subagent, do not read full `plan.md`, do not read
  implementation strategy, judge only from extracted proof artifacts + bounded
  verification evidence

#### Test evidence to collect

- Verification files: `{paths to tests, rules, or scripts}`
- Evidence mapping: `{P-refs -> test names / rule names / manual checks}`
- Commands: `{exact lint / typecheck / script / test commands}`
- Outputs: `{pass/fail summary, generated-case counts where applicable}`
- Runtime mutation candidates to assess:
  `{bound flips, removed guards, constant return, skipped normalization,
   bypassed branch/auth}`
- Static-proof gaps to assess:
  `{rule bypasses, files outside rule scope, formatter/lint blind spots}`

### File tree

Show touched files in a neotree-style tree. Use `▾` for expanded
directories, `●` for files. Mark `[M]` modify, `[C]` create,
`[D]` delete. Collapse non-scoped siblings with `(...)`. Keep
change descriptions to one line.

```text
▾ src/
  ▾ feature/
    ● module.ts                          [M] +newFunction, restructured logic
    ● helper.ts                          [C] new helper
  (...)
▾ test/
  ● feature.test.ts                      [M] +new test cases
  (...)
```

### Implementation strategy

<!-- Steps reference decisions by number. Phase if natural stages
     exist, flat if not. Each phase names its target file(s).
     Fold current-state facts into the relevant step instead of using a
     separate execution/codebase packet.
     For runtime tests: include framework, arbitraries, mock setup, and
     assertions inline — no separate Test implementation notes.
     Prefer near-real code in the repo language. Sketch only the non-obvious
     lines. For query-heavy work, show the real select/join/filter/group/order
     shape instead of `SELECT ...` placeholders. Show only the correct
     approach, no "NOT THIS / THIS" narratives.
     After rule/script/test implementation, run the context-minimized verifier
     against the extracted proof packet before moving to review. -->

1. `{path or symbol}` - {step referencing D1}

   Current touch point:

   ```typescript
   {path}::{symbol}({args}) -> {return}
   ```

   Current local shape:

   ```typescript
   {path}::{symbol}
     ...{existing nearby logic}...
     {decision-carrying line}  # D1
     ...
   ```

    ```python
    stmt = (
        select(...)
        .join(...)
        .where(...)
        .group_by(...)
        .order_by(...)
    )
    rows = (await session.execute(stmt)).mappings().all()
    return [{field: row[field]} for row in rows]
    ```

2. `{path or symbol}` - {step referencing D2}

   Existing proof hooks:

   - `{helper}` in `{path}` - {what existing fixture/helper already does}
   - `{helper}` in `{path}` - {what existing fixture/helper already does}

    ```python
    def test_{behavior}(...):
        seed_{fixture}(...)
        {refresh_or_execute}(...)
        assert {observable} == {expected}
    ```

### Acceptance gate

- [ ] `{validation command}` passes
- [ ] Properties {P-refs} hold with the planned enforcement
- [ ] Spec acceptance criteria verified by the evidence above
- [ ] `## Verification Gate` status is `passed`
- [ ] {plan-specific checks — 2-4 items: static rules, boundaries,
      preservation, performance budgets}

### Agent self-review (fill after implementation)

- Hardest: {which decision was hardest to implement}
- Least confident: {what might be wrong}
- Deviations: {what differs from the plan and why}

---

## Decisions log
- {date} - {decision} - {rationale}

## Errors
- {error} - attempt: {attempt} - resolution: {resolution}

## Verification Gate
- Status: pending
- Last run: none
- Verdict: not run
- Blocking issues: verifier not run

<!-- REVIEW: PENDING - add > [R]: comments inline. -->

## Review Gate
- Status: pending

## Resume
- Source: plan
- Phase: planning
- Gate: pending
- Verification Gate: pending
- Current Slice: draft review artifacts above the trust boundary
- Next Step: validate the plan and collect review approval
- Open Questions: none
- Files in Play: `.spine/features/{slug}/plan.md`, `.spine/features/{slug}/spec.md`

## State
- Phase: planning
- Verification Gate: pending

(End of file)
