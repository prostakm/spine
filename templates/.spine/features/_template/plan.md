# Feature: {FEATURE_NAME}

<!-- Human context only. Keep prose hard-wrapped at 100 chars.
     Bold only the smallest crucial fragment.
     Keep implementation details (component names, pixel specs, library
     choices) out of Context — those go in the agent zone Implementation
     strategy. Context answers: what's broken, what's the scope, what
     depends on it.
     Spec-derived fields carry forward approved spec facts for plan
     self-sufficiency. Reviewer skims for accuracy, does not re-approve.
     Only "Planning additions" needs deep reading.
     Criticality tags (use sparingly — only when the tag adds real signal):
       ⚠️  volatile: data loss, money errors, corruption, silent wrong results
       🔒  locks in: constrains future architecture or behavior
       🛡️  security: auth, permissions, PII, attack surface
       👁️  UX-critical: directly affects what users see or experience
     Append to decision headings, properties, rules, or edge cases.
     Most items get no tag. -->

## Context
- Spec: `.spine/features/{slug}/spec.md` (approved)
- Implementation startup rule: after approval, start from this `plan.md`;
  do not reload the sources above unless the plan is missing a needed fact or
  the code contradicts it
- User context: {from spec — goal, user, or trigger}
- Existing behavior: {from spec, enriched with technical detail}
- Scope: {from spec}

### Planning additions
<!-- Technical context discovered during planning that the spec didn't
     cover: actual files, APIs, error codes, data shapes, dependency
     constraints. Omit section if spec was complete. -->

- {new technical context, or omit entire subsection}

**Status:** DRAFT | REVIEW | ANNOTATED | APPROVED
**Scope:** {from spec — what changes, for whom}
**Risk:** LOW | MEDIUM | HIGH - {one phrase justifying}
<!-- Derived from spec Change type -->
**Strategy:** CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION
**Budget:** ~{N} min review above trust boundary

---

## Decisions

- Goal: {what this delivers — distilled from spec Problem}
- Approach: {technical strategy - 1-2 short lines}
- Risk: {risk} -> {mitigation}

<!-- For each decision ask:
     can a type, lint rule, or shared helper make this unreviewable later?
     If yes, note it in Poka-yoke later and add it to conventions backlog. -->

### 🔴 D1: {decision title} {⚠️|🔒|🛡️|👁️}

- Chose: {what}
- Over: {alt} - {why not}
- Locks: {what this commits to}
- Covered by: {P1, P2 | acceptance gate | manual review}
- Poka-yoke later: {type | lint | helper | none}

> ANNOTATION:

<!-- Repeat D2, D3... Max 7. If more, split the feature.
     For 🟡 REVIEW: same format as 🔴 GATE.
     For 🟢 TRUST: one line with property reference.
       - 🟢 T3: {title} — {one-line summary} ({P-refs})
       No Chose/Over/Locks expansion — agent owns these.
     Criticality tags are optional. Append ⚠️ 🔒 🛡️ 👁️ to the heading
     when the reason matters. Most decisions get no tag. -->

---

## Spec + proof

<!-- Delete the blocks that do not match your strategy. -->

<!-- CORRECTNESS -->

### Rules

<!-- Tag with [REQ-N] when the rule proves a spec requirement.
     Untagged rules are plan-discovered — reviewer pays extra attention. -->

**R1: {rule}** - {plain English} [REQ-{n}]

```text
{input conditions} -> {expected}
{input conditions} -> {expected}
```

```yaml
case: {only when one-line fixtures are too lossy}
when:
  {field}: {value}
then:
  {observable}: {expected}
```

### Properties
<!-- AUTHOR: human | human-validated | agent-proposed
     Append ⚠️ 🔒 🛡️ 👁️ after invariant when the reason matters. -->
- **P1:** {category}: {invariant} {⚠️|🔒|🛡️|👁️}
- **P2:** {category}: {invariant}

### Snapshot anchors

- {output worth locking}

### Edge cases

- {specific scenario} {⚠️ if catastrophic}

### Code sketch (optional)

```text
{function_name}({args}) -> {return}:
  ...{obvious setup}...
  {THE DECISION LINE}  # why this matters
  ...{obvious wiring}...
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
<!-- AUTHOR: human | human-validated | agent-proposed -->
- **P1:** preservation: {identical before and after}

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
<!-- AUTHOR: human | human-validated | agent-proposed -->
- **P1:** structural: {architecture invariant}

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
<!-- AUTHOR: human | human-validated | agent-proposed -->
- **P1:** {category}: {the violated invariant, now a property}

## Contracts

<!-- Skip when spec I/O already has complete types and no enrichment
     is needed. Include when planning discovers actual signatures,
     query shapes, or types the spec left abstract.
     Always include Data flow and Side effects when they exist. -->

### Data flow

```text
{source} -> {transform} -> {destination}
```

### Inputs

```text
{name}: {type}  # constraint
```

### Outputs

```text
{name}: {type}  # constraint
```

### Side effects

- ⚠ {DB write, event, external call}

---

<!-- TRUST BOUNDARY - reviewer stops here -->

## Agent instructions

### Codebase packet

This section makes the plan executable without broad re-reading.

#### Current signatures

```text
{path}::{symbol}({args}) -> {return}
{path}::{symbol}({args}) -> {return}
```

#### Local snippets

```text
{path}::{symbol}
  ...{existing nearby logic}...
  {decision-carrying line}
  ...
```

#### Test hooks and fixtures

- `{helper}` in `{path}` - {what existing fixture/helper already does}
- `{helper}` in `{path}` - {what existing fixture/helper already does}

#### Generated/runtime names

- `{exact schema/type/export name}` in `{path}` - {why it matters}
- `{exact route/query key/test name}` - {why it matters}

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
     For tests: include framework, arbitraries, mock setup, and
     assertions inline — no separate Test implementation notes.
     Show only the correct approach, no "NOT THIS / THIS" narratives. -->

1. `{path or symbol}` - {step referencing D1}

   ```text
   {logic sketch or pseudocode for the non-trivial part}
   ```

2. `{path or symbol}` - {step referencing D2}

   ```text
   {logic sketch or pseudocode for the non-trivial part}
   ```

### Acceptance gate

- [ ] `{test command}` passes
- [ ] Properties {P-refs} hold (verified by tests, min 100 generated cases)
- [ ] Spec acceptance criteria verified by tests above
- [ ] {plan-specific checks — 2-4 items: arch boundaries, preservation,
      performance budgets}

### Agent self-review (fill after implementation)

- Hardest: {which decision was hardest to implement}
- Least confident: {what might be wrong}
- Deviations: {what differs from the plan and why}

---

## Decisions log
- {date} - {decision} - {rationale}

## Errors
- {error} - attempt: {attempt} - resolution: {resolution}

<!-- REVIEW: PENDING - add > [R]: comments inline. -->

## Review Gate
- Status: pending

## Resume
- Source: plan
- Phase: planning
- Gate: pending
- Current Slice: draft review artifacts above the trust boundary
- Next Step: validate the plan and collect review approval
- Open Questions: none
- Files in Play: `.spine/features/{slug}/plan.md`, `.spine/features/{slug}/spec.md`

## State
- Phase: planning
