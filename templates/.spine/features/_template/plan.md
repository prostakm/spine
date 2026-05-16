# Feature: {slug}

> **Story:**
> {Line 1 — what changes.}
> {Line 2 — gap it closes.}
> {Line 3 — win after ship.}

## Status
- **Status:** {DRAFT|REVIEW|APPROVED|...}
- **Strategy:** {CORRECTNESS|EQUIVALENCE|STRUCTURAL|REGRESSION}
- **Risk:** {LOW|MEDIUM|HIGH} — {one-line justification}
- **Scope:** {one-line scope statement}

## System view

```text
{ASCII diagram — components and relationships}
{Mark [NEW], [M], [UNCHANGED], locked boundaries}
```

## Behaviors

- Flow A — {name} ({write path | read path | lifecycle})
- Flow B — {name} ({when applicable})

System-wide invariants:

- **P1** — {invariant as single fact}
  - holds: {site}
  - test: `{test_name}`
  - never: {forbidden behavior, if applicable}
  <details><summary>{deeper rationale title, if any}</summary>

  - {deeper bullets}
  </details>

## Flow A — {name}

```text
{ASCII flow diagram}
```

### A.1 — {step name}

> **Step intent:** {One or two sentences on what this step does and why.}

- {🔴|🟡} **D1** — {decision title}
  <details><summary>chose: {what}</summary>

  - over: {alternative}
  - why not: {fragment}
  - consequence: {what this commits to}
  </details>

- **R1** — {rule as fact}
  - holds: {site}
  - test: `{test_name}`
  - never: {forbidden behavior}

- **P2** — {step-local invariant}
  - holds: {site}
  - test: `{test_name}`
  - pattern: {implementation pattern, if useful}
  - never: {forbidden behavior}

- → impl: [I1](#i1), [I2](#i2)

### A.2 — {step name}

> **Step intent:** {One or two sentences on what this step does and why.}

- → impl: [I3](#i3)

## Flow B — {name} (when applicable)

```text
{ASCII flow diagram}
```

### B.1 — {step name}

> **Step intent:** {One or two sentences on what this step does and why.}

- → impl: [I4](#i4)

## Acceptance matrix

| ID | Invariant / rule | Test | Strategy |
|----|------------------|------|----------|
| P1 | ...              | ...  | ...      |
| R1 | ...              | ...  | ...      |

---

<!-- ═══════════════════════════════════════════════════════ -->
<!-- TRUST BOUNDARY — reviewer stops here                   -->
<!-- ═══════════════════════════════════════════════════════ -->

## Agent instructions

### Verification packet

- Strategy: `{strategy}`
- Properties: `{P-refs}`
- Rules: `{R-refs}`
- Verifier constraints: {bounded, fresh subagent, judge from {evidence}}

### File manifest

```text
{root}/
├── {file}                         [M] → I1, I2
├── {file}                         [C] → I3
└── {file}                         [D] → I4
```

### Implementation

#### I1 — {short title} <a id="i1"></a>

- **Intent:** {one sentence; agent fallback if diff doesn't apply}
- **References:** D1, P1, R1
- **Critical:** 🔴

```diff
--- a/{path}
+++ b/{path}
@@ -1,3 +1,4 @@
 {context}
-{old}
+{new}
```

#### I2 — {short title} <a id="i2"></a>

- **Intent:** {one sentence; agent fallback if diff doesn't apply}
- **References:** P2

```diff
--- /dev/null
+++ b/{new-path}
@@ -0,0 +1,3 @@
+{new file contents}
```

#### I3 — {short title} <a id="i3"></a>

- **Intent:** {one sentence; agent fallback if diff doesn't apply}
- **References:** {D/P/R refs}

```diff
--- a/{path}
+++ b/{path}
@@ -1,2 +1,2 @@
-{old}
+{new}
```

#### I4 — {short title} <a id="i4"></a>

- **Intent:** {one sentence; agent fallback if diff doesn't apply}
- **References:** {D/P/R refs}

```diff
--- a/{path}
+++ b/{path}
@@ -1,2 +1,2 @@
-{old}
+{new}
```

### Acceptance gate

- [ ] {validation command} passes
- [ ] Properties {P-refs} hold
- [ ] {plan-specific checks}

### Agent self-review (fill after implementation)

- Hardest: ___
- Least confident: ___
- Deviations from plan: ___

---

## Decisions log
- {date} — {decision} — {rationale}

## Errors
- {error} — attempt: {attempt} — resolution: {resolution}

## Verification Gate
- Status: pending
- Last run: none
- Verdict: not run

<!-- REVIEW: PENDING — add R> comments inline. -->

## Review Gate
- Status: pending

## Resume
- Source: plan
- Phase: planning
- Gate: pending
- Verification Gate: pending
- Current Slice: {what state the plan is in}
- Next Step: {what happens next}
- Open Questions: {any}
- Files in Play: {paths}

## State
- Phase: planning
- Verification Gate: pending
