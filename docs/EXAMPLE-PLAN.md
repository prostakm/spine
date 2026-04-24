# Example Plans

## CORRECTNESS Example

````markdown
# Feature: payroll-rounding

## Changed Surface

```text
payroll/
├── calculator.py                      [M] final-only rounding path
└── tests/
    └── test_payroll.py               [M] fixture + property coverage
```

## Context

- Goal: fix net-pay rounding in payroll exports.
- Gap: components round independently before final net pay.
- In: net-pay math only.
- Out: tax rules and export shape.
- Constraints: finance worksheet examples stay authoritative.

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

> [!CAUTION] D1: Final-only rounding
> - **Chose:** banker rounding at the final net-pay step.
> - **Over:** per-component half-up rounding — disagrees with finance worksheet.
> - **Consequence:** all callers use one shared calculator path.

---

## Spec + proof

### Rules

**R1: Final-only rounding** — round once after tax and deduction totals.

- When gross is `40h * 25.125` with no deductions, net pay is `$1,005.00`.
- When gross is `12h * 19.995` with flat `10%` tax, net pay is `$215.95`.
- When hours are zero, net pay is `$0.00`.

### Properties
<!-- AUTHOR: human -->

> [!CAUTION] **P1** — `runtime` — `human`
> **Invariant:** range: net pay is never negative.
> **Evidence:** property test over generated hours, rates, tax, and deductions.

- **P2** — `runtime` — `human`
  Invariant: relational: increasing hours never decreases net pay.
  Evidence: property test over monotonic input pairs.

### Edge cases

- zero-hour timesheet
- deductions larger than gross

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

### Implementation strategy

1. `payroll/calculator.py::calculate_net_pay` - implement D1 in the existing
   calculator path.

   Current touch point:

   ```python
   payroll/calculator.py::calculate_net_pay(hours, rate, tax, deductions) -> Money
   ```

   Current local shape:

   ```python
   gross = round_component(hours * rate)
   taxed = round_component(apply_tax(gross, tax))
   return money(taxed - sum(deductions))
   ```

   ```python
   gross = hours * rate
   taxed = apply_tax(gross, tax)
   return money(round_final(max(taxed - sum(deductions), 0)))
   ```

2. `tests/test_payroll.py` - keep the approved proof in the runtime suite.

   Existing proof hooks:

   - `money_examples` in `tests/test_payroll.py` - worksheet-backed fixtures

   ```python
   @given(hours=hours(), rate=rates(), tax=taxes(), deductions=deductions())
   def test_net_pay_never_negative(...):
       assert calculate_net_pay(...) >= money(0)
   ```

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

## Changed Surface

```text
web/
├── src/slices/match-details/page.tsx  [M] ready-state UI only
├── eslint/slice-boundaries.js         [C] page import boundary rule
└── src/test/match-details-page.test.tsx [M] runtime branch coverage
```

## Context

- Goal: refresh the ready page without moving query or controller logic.
- Gap: page code is drifting toward route/query ownership.
- In: ready-state UI and boundary enforcement.
- Out: controller, query, and API orchestration.
- Constraints: `page.tsx` may hold only transient visual state.

**Status:** REVIEW
**Scope:** Preserve slice boundary while refreshing the ready-state view
**Risk:** MEDIUM - visual work can hide architectural drift
**Strategy:** STRUCTURAL

---

## Decisions

- Goal: refresh the ready UI without changing slice ownership.
- Approach: enforce the page boundary statically, then update the view.
- Risk: page imports query logic -> block it with an eslint rule.

> [!IMPORTANT] D1: Enforce page ownership statically
> - **Chose:** add an eslint rule banning query/API imports from routed page files.
> - **Over:** page-boundary unit tests only — weaker and easier to bypass.
> - **Consequence:** future boundary regressions fail in lint before review.

---

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

> [!NOTE] **P1** — `static` — `human`
> **Invariant:** structural: `page.tsx` never imports query hooks or API modules.
> **Evidence:** eslint rule in `web/eslint/slice-boundaries.js` + `pnpm lint`.

- **P2** — `runtime` — `human`
  Invariant: preservation: ready page tab switching remains local UI state.
  Evidence: page test for default tab and switched tab.

<!-- TRUST BOUNDARY - reviewer stops here -->

## Agent instructions

### Implementation strategy

1. `web/eslint/slice-boundaries.js` - enforce D1 before touching the page.

   Current touch point:

   ```javascript
   web/eslint/slice-boundaries.js::rules["page-boundary"](context) -> RuleListener
   ```

   ```javascript
   if (isRoutedPage(filename) && importsQueryLayer(source)) {
     context.report(...)
   }
   ```

2. `web/src/slices/match-details/page.tsx` - keep page logic view-only.

   Current local shape:

   ```tsx
   const [activeTab, setActiveTab] = useState("summary")
   return <ReadyView activeTab={activeTab} onTabChange={setActiveTab} />
   ```

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
