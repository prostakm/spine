# Example Plans

## CORRECTNESS Example

````markdown
# Feature: payroll-rounding

## Changed code surface

```text
payroll/calculator.py                              [M] final rounding behavior
tests/test_payroll.py                             [M] fixture + property coverage
```

## Context
- Spec: `.spine/features/payroll-rounding/spec.md` (approved)
- Goal: fix net-pay rounding in payroll exports.
- Current gap: components round independently before final net pay.
- Scope: change net-pay math only.
- Hard constraints: finance worksheet examples stay authoritative.

**Status:** REVIEW
**Scope:** Correct net-pay rounding for hourly payroll exports
**Risk:** MEDIUM - touches money math
**Strategy:** CORRECTNESS

---

## Decisions

- Goal: net pay matches finance rules for supported timesheets.
- Approach: centralize rounding in one calculator, then prove it with
  fixtures and properties.
- Risk: rule mismatch -> lock worksheet examples first.

### D1: Final-only rounding ⚠️

- Chose: banker rounding at the final net-pay step.
- Over: per-component half-up rounding - disagrees with finance worksheet.
- Consequence: all callers use one shared calculator path.

> ANNOTATION:

## Spec + proof

### Rules

**R1: Final-only rounding** - round once after tax and deduction totals.

- When gross is `40h * 25.125` with no deductions, net pay is `$1,005.00`.
- When gross is `12h * 19.995` with flat `10%` tax, net pay is `$215.95`.
- When hours are zero, net pay is `$0.00`.

### Properties
<!-- AUTHOR: human -->
- **P1**
  - Invariant: range: net pay is never negative ⚠️
  - Enforcement: runtime
  - Why: depends on calculated values across many inputs.
  - Evidence: property test over generated hours, rates, tax, and deductions.
- **P2**
  - Invariant: relational: increasing hours never decreases net pay.
  - Enforcement: runtime
  - Why: requires comparing computed outcomes across input pairs.
  - Evidence: property test over monotonic input pairs.

### Edge cases

- zero-hour timesheet
- deductions larger than gross ⚠️

## Contracts

### Inputs

```python
hours: Decimal
rate: Decimal
deductions: list[Decimal]
```

### Outputs

```python
Money(cents: int, currency: str)
```

<!-- TRUST BOUNDARY - reviewer stops here -->

## Agent instructions

### Verification evidence

#### Verifier packet

- Strategy: `CORRECTNESS`
- Properties: `P1-P2`
- Rules / invariants to extract: `R1`

#### Test evidence to collect

- Verification files: `tests/test_payroll.py`
- Evidence mapping: `P1-P2 -> property tests`, `R1 -> fixture test`
- Commands: `pytest tests/test_payroll.py`
````

## STRUCTURAL Example

````markdown
# Feature: match-details-boundary

## Changed code surface

```text
web/src/slices/match-details/page.tsx              [M] ready-state UI only
web/eslint/slice-boundaries.js                     [C] boundary rule for page imports
web/src/test/match-details-page.test.tsx           [M] runtime branch coverage
```

## Context
- Goal: refresh the ready page without moving query or controller logic.
- Current gap: page code is drifting toward route/query ownership.
- Scope: keep route/controller/query orchestration unchanged.
- Hard constraints: `page.tsx` may hold only transient visual state.

**Status:** REVIEW
**Scope:** Preserve slice boundary while refreshing the ready-state view
**Risk:** MEDIUM - visual work can hide architectural drift
**Strategy:** STRUCTURAL

---

## Decisions

- Goal: refresh the ready UI without changing slice ownership.
- Approach: enforce the page boundary statically, then update the view.
- Risk: page imports query logic -> block it with an eslint rule.

### D1: Enforce page ownership statically 👁️

- Chose: add an eslint rule banning query/API imports from routed page files.
- Over: page-boundary unit tests only - weaker and easier to bypass.
- Consequence: future boundary regressions fail in lint before review.

## Spec + proof

### Architecture constraints

- `page.tsx` does not import query hooks, API clients, or router loaders.

### Boundary behavior

```text
ready state:
  page renders local visual state only
  controller owns async branching and data fetching
```

### Smoke tests

- ready page still switches tabs locally.

### Properties
<!-- AUTHOR: human -->
- **P1**
  - Invariant: structural: `page.tsx` never imports query hooks or API modules.
  - Enforcement: static
  - Why: this is a source-shape rule; lint is stronger than a runtime test.
  - Evidence: eslint rule in `web/eslint/slice-boundaries.js` + `pnpm lint`.
- **P2**
  - Invariant: preservation: ready page tab switching remains local UI state.
  - Enforcement: runtime
  - Why: user-visible behavior still needs render proof.
  - Evidence: page test for default tab and switched tab.

<!-- TRUST BOUNDARY - reviewer stops here -->

## Agent instructions

### Verification evidence

#### Verifier packet

- Strategy: `STRUCTURAL`
- Properties: `P1-P2`
- Rules / invariants to extract: architecture constraints

#### Test evidence to collect

- Verification files:
  `web/eslint/slice-boundaries.js`,
  `web/src/test/match-details-page.test.tsx`
- Evidence mapping: `P1 -> lint rule`, `P2 -> page test`
- Commands: `pnpm lint`, `pnpm test --run src/test/match-details-page.test.tsx`
````
