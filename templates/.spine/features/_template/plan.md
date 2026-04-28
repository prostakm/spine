# Feature: {FEATURE_NAME}

<!--
Navigation:
  gd on a [link](#anchor) jumps to heading.
  gf on a path opens the file.
  Slug rule: lowercase, drop punctuation, spaces→dash.

Style:
  - Caveman phrasing in lists. Prose only for Why grouped / What changes.
  - Bullet points over paragraphs.
  - No markdown tables. Use fenced `text` blocks if tabular data needed.
  - Bold only the smallest crucial fragment.
  - Hard-wrap prose at 100 chars.

Criticality tags (use sparingly on decisions):
  > [!CAUTION]   data loss, money, corruption, silent wrong results
  > [!WARNING]   directly affects what users see or experience
  > [!IMPORTANT] locks in: constrains future architecture or behavior
  > [!TIP]       default / no tag — render as plain heading
-->

## Overview

### System flow

```text
┌─ {concern} ─────────────────────────────────────────┐
│ {file path}                                  [M]    │
│ {one short sentence on what changes here}           │
└────────┬────────────────────────────────────────────┘
         │ {verb: used by / called by / consumed by}
         ▼
┌─ {next concern} ────────────────────────────────────┐
│ ...                                                 │
└─────────────────────────────────────────────────────┘
```

### File map

```text
{root-pkg}/
├── {file}                              [M] short reason
├── {file}                              [C] short reason
├── {sibling-dir}/                      ...
└── ...
```

## Context

- Spec: `.spine/features/{slug}/spec.md` (approved) — or "(none, intent here)"
- Goal: {one line, user outcome}
- Gap: {what's wrong now}
- In: {what changes in this slice}
- Out: {what's deferred or unchanged}
- Constraints: {hard limits}

**Status:** DRAFT | REVIEW | ANNOTATED | APPROVED
**Scope:** {one sentence}
**Risk:** LOW | MEDIUM | HIGH — {one phrase}
**Strategy:** CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION

---

## Chapters

### Chapter 1: {name}

**Why grouped:** {1–3 short prose sentences — why this is one review unit}

**What changes:** {1–2 sentences — system-level summary}

**Decisions:**

> [!IMPORTANT] **D1:** {title}
> - **Chose:** {what}
> - **Over:** {alt} — {why not}
> - **Consequence:** {what this locks in}
>   ([code](#modify-path-lines-start-end) or other anchor)

**Provisions:**

*Properties:*

- **P0** — `static | runtime` — `human | human-validated | agent-proposed` —
  {short label}.
  - Invariant: {what must hold}
  - Invariant: {additional invariant if any}
  - Evidence: [`test_name`](#test_name) +
    [other test or code anchor](#anchor).

*Rules / fixtures (delete if not used):*

**R1: {name}**

- {fixture case 1 in caveman form}
- {fixture case 2}

*Boundary behavior (delete if not used):*

```text
{operation} → {outcome}
{operation} → {outcome}
```

*Edge cases:*

- {case in caveman form, 1 line}
- {case}

### Cross-chapter

(none) — or list decisions/provisions that genuinely span chapters.

---

## Contracts

(Delete if no boundary changes)

### Inputs / Outputs

```{lang}
{shapes}
```

### Side effects

- ⚠ {effect}

═══════════════ TRUST BOUNDARY — reviewer stops here ═══════════════

## Implementation tracks

### Track 1: {name}

**Depends on:** {prior tracks or none}.

**Constraints:**

- {imperative directive in caveman form}
- {imperative directive}

**Code:**

#### Modify {path} lines {start}-{end}

```diff
@@ {symbol or local region} ({path}:{start}-{end}) @@
 {enough unchanged context for safe placement}
-{removed line}
+{added line}
 {enough unchanged context for safe placement}
```

#### New file {path}

```{lang}
{full contents}
```

**Tests:**

#### `test_name`

*Unit | Hypothesis property | Snapshot | Parametrized | Component | Hook*.
Proves PX.

- In: {input/setup, code-shaped where helpful}
- Assert: {expectation, code-shaped where helpful}
- Note: {optional one-line note}

**Verify:**

```bash
{commands}
```

**Green when:**

- {criterion referencing test names}
- {criterion}

## Verification evidence

### Verifier packet

- Strategy: `{STRATEGY}`.
- Test files: {list}.
- Each test cites its provision in a docstring/comment.
- Verifier extracts cited IDs; confirms every chapter provision has at
  least one citing test.
- Verifier constraints: fresh subagent; chapter provisions + test files
  only; no implementation code.

### Mutation candidates

- {what could break and which test catches it}

### Static-proof gaps

- {what static check would miss}

## Verification Gate

- Status: pending
- Last run: never
- Verdict: pending
- Blocking issues: none yet

## Acceptance gate

- [ ] Track 1 green — {summary}
- [ ] Track 2 green — {summary}
- [ ] Every chapter provision has at least one citing test
- [ ] {strategy-specific}

## Review Gate

- Status: pending

## State

- Phase: planning
- Verification Gate: pending

## Resume

- Source: plan
- Phase: planning
- Gate: pending
- Current Slice: review and approve plan
- Next Step: reviewer reads chapters top-down, marks `> [R]: APPROVED`
- Open Questions: {list}
- Verification Gate: pending
- Files in Play: `.spine/features/{slug}/plan.md`

### Agent self-review

(Filled after implementation completes.)

- Hardest: {decision hardest to implement}
- Least confident: {what might be wrong}
- Deviations: {what differs from plan and why}
