# Feature: {FEATURE_NAME}

## Context
- Project: `.spine/project.md`
- Conventions: `.spine/conventions.md`
- Progress: `.spine/progress.md`
- Spec: `.spine/features/{slug}/spec.md` (if present)

**Status:** DRAFT | REVIEW | ANNOTATED | APPROVED
**Scope:** {one sentence - what changes, for whom}
**Risk:** LOW | MEDIUM | HIGH - {one phrase justifying}
**Strategy:** CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION

---

## Decisions

**Goal:** {what this delivers - one sentence}

**Approach:** {technical strategy - 1-2 sentences}

**Rejected options (only if informative):**
- {alt} - {why not}

**Key risks (only if non-obvious):**
- {risk} -> {mitigation}

### D1: {decision title}

**Chosen:** {what}
**Over:** {alt} - {why not}
**Consequence:** {what this locks in}

> ANNOTATION:

<!-- Repeat D2, D3... Max 7. If more, split the feature. -->

---

## Spec + proof

<!-- PROPERTY AUTHORSHIP RULE
     Properties are the primary proof artifact. They live above the trust boundary
     because the REVIEWER — not the agent — is responsible for their correctness.

      - human:           reviewer wrote it. Trusted proof.
      - human-validated: agent proposed it, reviewer confirmed with > [R]: ✓. Trusted.
      - agent-proposed:  agent wrote it, not yet validated. NOT trusted as proof.

      Agent implements property tests below the trust boundary.
      Agent MUST NOT modify human-authored property statements during implementation.
      If implementation reveals a property is wrong → STOP, propose revision, wait for > [R]: approval.
-->

<!-- Delete the blocks that don't match your strategy. -->

<!-- CORRECTNESS -->

### Rules

**R1: {rule}** - {plain English}

```text
when: {compact condition}
then: {expected behavior}
when: {compact condition}
then: {expected behavior}
```

```yaml
case: {only when one-line fixtures are too lossy}
when:
  {field}: {value}
  {field}: {value}
then:
  {observable}: {expected}
```

### Properties
<!-- AUTHOR: human | human-validated | agent-proposed -->
- **P1:** {category}: {invariant}
- **P2:** {category}: {invariant}

### Snapshot anchors

- {output worth locking}

### Edge cases

- {specific scenario}

<!-- EQUIVALENCE -->

### Equivalence anchor

**What must not change:** {be specific}
**Granularity:** exact | tolerance | structural
**Capture:** snapshot before, assert after

### Existing suite

**All tests in** {scope} **pass unmodified.**
If any assertion changes -> escalate.

### Properties
<!-- AUTHOR: human | human-validated | agent-proposed -->
- **P1:** preservation: {output for all valid inputs is identical before and after}

### Delta (perf only)

- {measurable improvement}

<!-- STRUCTURAL -->

### Architecture constraints

- {import rule, permission check, migration constraint}

### Boundary behavior

- `when: {request + context} -> then: {status + shape}`
- `when: {request + context} -> then: {status}`
- `when: {request + context} -> then: {status}`

### Smoke tests

- {wiring proof}

### Properties
<!-- AUTHOR: human | human-validated | agent-proposed -->
- **P1:** structural: {architecture invariant}

<!-- REGRESSION -->

### Reproduction

**Test:** {assertion}
**Expected:** {correct}
**Actual:** {buggy}

### Blast radius

**Scope:** {what else breaks}
**Verify:** {what suite to run}

### New invariant

- {property this bug reveals}

### Properties
<!-- AUTHOR: human | human-validated | agent-proposed -->
- **P1:** {category}: {the violated invariant, now a property}

## Contracts

<!-- Skip for EQUIVALENCE and REGRESSION unless interfaces change. -->

### Inputs

```text
{types - dataclass, TypedDict, or plain signature}
```

### Outputs

```text
{types}
```

### Side effects

- {DB write, event, external call}

---

<!-- TRUST BOUNDARY - reviewer stops here -->

## Agent instructions

### File manifest

- `CREATE path/to/file`
  - symbols: `{new symbol}`, `{new symbol}`
  - change: {what this file will contain}
- `MODIFY path/to/file`
  - symbols: `{existing symbol}`, `{new helper}`
  - change: {what changes in this file}

### Implementation strategy

1. `{path or symbol}` - {step referencing D1}

   ```text
   {code snippet or pseudocode for the non-trivial part}
   ```

2. `{path or symbol}` - {step referencing D2}

   ```text
   {code snippet or pseudocode for the non-trivial part}
   ```

### Test implementation notes

- {parametrize, property framework hints, snapshot format}
- {property framework for this stack: hypothesis (Python), fast-check (JS/TS),
  jqwik (Java), rapid (Go), FsCheck (.NET), QuickCheck (Haskell)}
- {exact test names or suites to add/update}

### Acceptance gate

- [ ] All properties from Spec + proof implemented as tests
- [ ] Property tests pass (minimum 100 generated cases per property)
- [ ] No property statements modified without reviewer approval
- [ ] {strategy-specific checks}

---

## Decisions log
- {date} - {decision} - {rationale}

## Errors
- {error} - attempt: {attempt} - resolution: {resolution}

<!-- REVIEW: PENDING - add > [R]: comments inline, mark > [R]: APPROVED when done -->

## Review Gate
- Status: pending

## State
- Phase: planning
