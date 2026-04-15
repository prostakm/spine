# Feature: {FEATURE_NAME}

<!-- Human context only. Keep prose hard-wrapped at 100 chars.
     Bold only the smallest crucial fragment. -->

## Context
- Project: `.spine/project.md`
- Conventions: `.spine/conventions.md`
- Progress: `.spine/progress.md`
- Spec: `.spine/features/{slug}/spec.md` (if present)
- User context: {goal, user, or trigger in one line}
- Existing behavior: {current boundary or baseline}
- Scope choice: {chosen scope or none}
- Dependency notes: {upstream contract, file, or none}

**Status:** DRAFT | REVIEW | ANNOTATED | APPROVED
**Scope:** {one sentence - what changes, for whom}
**Risk:** LOW | MEDIUM | HIGH - {one phrase justifying}
**Strategy:** CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION
**Budget:** ~{N} min review above trust boundary

---

## Decisions

- Goal: {what this delivers - one sentence}
- Approach: {technical strategy - 1-2 short lines}
- Risk: {risk} -> {mitigation}

<!-- For each decision ask:
     can a type, lint rule, or shared helper make this unreviewable later?
     If yes, note it in Poka-yoke later and add it to conventions backlog. -->

### 🔴 D1: {decision title}

- Chose: {what}
- Over: {alt} - {why not}
- Locks: {what this commits to}
- Covered by: {P1, P2 | acceptance gate | manual review}
- Poka-yoke later: {type | lint | helper | none}

> ANNOTATION:

<!-- Repeat D2, D3... Max 7. If more, split the feature. -->

---

## Spec + proof

<!-- Delete the blocks that do not match your strategy. -->

<!-- CORRECTNESS -->

### Rules

**R1: {rule}** - {plain English}

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
<!-- AUTHOR: human | human-validated | agent-proposed -->
- **P1:** {category}: {invariant}
- **P2:** {category}: {invariant}

### Snapshot anchors

- {output worth locking}

### Edge cases

- {specific scenario}

### Code sketch (optional)

```text
{function_name}({args}) -> {return}:
  ...{obvious setup}...
  {THE DECISION LINE}  # why this matters
  ...{obvious wiring}...
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

### Flow sketch (optional)

```text
{source} -> {selector or guard}
{condition}:
  yes -> {path A}
  no  -> {path B}
```

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

<!-- Skip for EQUIVALENCE and REGRESSION unless interfaces change. -->

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

### File manifest

- `CREATE path/to/file`
  - symbols: `{new symbol}`, `{new symbol}`
  - change: {what this file will contain}
- `MODIFY path/to/file`
  - symbols: `{existing symbol}`, `{new helper}`
  - change: {what changes in this file}
- `DELETE path/to/file` (if applicable)
  - reason: {why removed}

### Implementation strategy

<!-- Steps reference decisions by number. Phase if natural stages exist, flat if not. -->

1. `{path or symbol}` - {step referencing D1}

   ```text
   {logic sketch or pseudocode for the non-trivial part}
   ```

2. `{path or symbol}` - {step referencing D2}

   ```text
   {logic sketch or pseudocode for the non-trivial part}
   ```

### Test implementation notes

- {parametrize, property framework hints, snapshot format}
- {framework: hypothesis | fast-check | jqwik | rapid | FsCheck | QuickCheck}
- {exact test names or suites to add/update}

### Acceptance gate

- [ ] All properties from Spec + proof implemented as tests
- [ ] Property tests pass (minimum 100 generated cases per property)
- [ ] No property statements modified without reviewer approval
- [ ] {strategy-specific checks}

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
