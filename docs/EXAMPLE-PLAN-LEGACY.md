# Example Plan

The example below uses the v15 plan format (chapters above, tracks below,
anchored cross-links, full diff snippets with file/line locations, In/Assert
test specs, caveman phrasing). It demonstrates a CORRECTNESS strategy across
a realistic full-stack feature.

Older phase-based and v6 flat plans are obsolete; rewrite them to this v15 shape.

````markdown
# Feature: multi-state-tax-allocation

## Overview

### System flow

```text
┌─ Allocation engine ─────────────────────────────────┐
│ tax/allocation.py                            [M]    │
│ Split wages by worked-state days.                   │
│ tax/models.py                                [M]    │
│ Store allocation inputs and outputs.                │
└────────┬────────────────────────────────────────────┘
         │ consumed by
         ▼
┌─ Payroll tax service ───────────────────────────────┐
│ payroll/tax_service.py                       [M]    │
│ Read allocations before withholding math.           │
└────────┬────────────────────────────────────────────┘
         │ proved by
         ▼
┌─ Tests ─────────────────────────────────────────────┐
│ tests/test_tax_allocation.py                 [C]    │
│ Fixtures + properties for allocation rules.         │
│ tests/test_tax_api.py                        [C]    │
│ API smoke proof behind feature flag.                │
└─────────────────────────────────────────────────────┘
```

### File map

```text
payroll/
├── tax/
│   ├── allocation.py                 [M] allocation selector + rounding
│   └── models.py                     [M] input/output dataclasses
├── payroll/
│   └── tax_service.py                [M] reads allocation results
└── tests/
    ├── test_tax_allocation.py        [C] rules + properties
    └── test_tax_api.py               [C] feature-flag smoke
```

## Context

- Spec: `.spine/features/multi-state-tax-allocation/spec.md` (approved)
- Goal: allocate taxable wages across worked states before withholding.
- Gap: current payroll uses resident state for all wages.
- In: wage allocation, rounding, tax-service integration, tests.
- Out: reciprocity agreements, amended returns, UI editor.
- Constraints: cents conserved; no floats; feature flag gates API output.

**Status:** REVIEW
**Scope:** Multi-state taxable-wage allocation for one payroll run.
**Risk:** HIGH — money math + tax reporting.
**Strategy:** CORRECTNESS

---

## Chapters

### Chapter 1: Allocation engine

**Why grouped:** Allocation math, rounding, and conservation are one review unit because a
rounding choice changes taxable wages. Reviewing them together catches money drift.

**What changes:** Add an allocation selector that splits gross wages by state work days and
rounds residual cents into the largest remainder bucket.

**Decisions:**

> [!CAUTION] **D1:** Integer cents only
> - **Chose:** inputs and outputs are integer cents; percentages are fractions.
> - **Over:** decimal floats — silent penny drift.
> - **Consequence:** allocation code owns residual cents
>   ([code](#modify-taxallocationpy-lines-1-34), [`test_allocation_conserves_cents`](#test_allocation_conserves_cents)).

> [!IMPORTANT] **D2:** Largest remainder residual
> - **Chose:** floor each share, then distribute leftover cents by largest fractional remainder.
> - **Over:** put all residual on resident state — biased and hard to explain.
> - **Consequence:** deterministic tie-break required by state code
>   ([code](#modify-taxallocationpy-lines-1-34), [`test_residual_uses_largest_remainder`](#test_residual_uses_largest_remainder)).

**Provisions:**

*Properties:*

- **P0** — `runtime` — `human` — cents conserved.
  - Invariant: sum allocated cents equals gross taxable cents.
  - Evidence: [`test_allocation_conserves_cents`](#test_allocation_conserves_cents).
- **P1** — `runtime` — `human` — no negative allocations.
  - Invariant: each state allocation is `>= 0` cents.
  - Evidence: [`test_allocation_never_negative`](#test_allocation_never_negative).
- **P2** — `runtime` — `human` — largest remainder wins residual.
  - Invariant: leftover cents go to highest fractional remainder; ties sort by state code.
  - Evidence: [`test_residual_uses_largest_remainder`](#test_residual_uses_largest_remainder).

*Rules / fixtures:*

**R1: single-state pass-through**

- `CA: 10 days`, gross `$1000.00` → `CA: $1000.00`.

**R2: equal split**

- `CA: 5`, `NY: 5`, gross `$1000.00` → `CA: $500.00`, `NY: $500.00`.

**R3: residual cent**

- `CA: 1`, `NY: 2`, gross `$1000.00` → total conserved; extra cent to largest remainder.

*Edge cases:*

- Zero gross → all allocations zero.
- Zero total days → validation error before allocation.
- Unknown state code → validation error; no silent bucket.

### Chapter 2: Tax service integration

**Why grouped:** The tax service is where allocation becomes user-visible withholding. It must
consume selector output without duplicating allocation logic.

**What changes:** Tax service asks the allocation selector for state taxable wages, then runs
existing withholding calculators per state.

**Decisions:**

> [!IMPORTANT] **D3:** Selector boundary, not service math
> - **Chose:** `tax_service.py` calls `allocate_taxable_wages` and treats result as read-only.
> - **Over:** inline split inside tax service — duplicates rules and hides residual handling.
> - **Consequence:** allocation reads → selector only
>   ([code](#modify-payrolltax_servicepy-lines-1-18), [`test_tax_service_uses_allocator`](#test_tax_service_uses_allocator)).

**Provisions:**

*Properties:*

- **P3** — `runtime` — `human-validated` — service preserves total taxable wages.
  - Invariant: tax service state taxable total equals run gross taxable cents.
  - Evidence: [`test_tax_service_uses_allocator`](#test_tax_service_uses_allocator).
- **P4** — `static` — `agent-proposed` — no duplicate allocation math.
  - Invariant: tax service imports selector; no local day-ratio math.
  - Evidence: [`test_tax_service_has_no_ratio_math`](#test_tax_service_has_no_ratio_math).

*Rules / fixtures:*

**R4: resident + worked state**

- Resident `CA`, worked `CA + NY` → withholding lines for both states.

**R5: feature flag off**

- Flag off → old resident-only behavior preserved.

*Boundary behavior:*

```text
allocate enabled + multi-state days → per-state taxable wages
allocate disabled + multi-state days → resident taxable wages only
invalid work-day total → validation error before withholding
```

*Edge cases:*

- Duplicate state entries → merge before allocation.
- State with zero days → omitted from withholding input.

### Chapter 3: API contract and rollout

**Why grouped:** API shape and rollout flag decide what external callers see. They belong with
acceptance edge cases, not with internal allocation math.

**What changes:** API includes allocation details only behind `multi_state_tax_allocation` and
keeps old response shape otherwise.

**Decisions:**

> [!WARNING] **D4:** Flag-gated response expansion
> - **Chose:** add `state_allocations` only when feature flag is enabled.
> - **Over:** always include empty array — client-visible contract churn.
> - **Consequence:** rollout safe for existing API consumers
>   ([code](#modify-apiresponsespy-lines-20-38), [`test_api_hides_allocations_when_flag_off`](#test_api_hides_allocations_when_flag_off)).

**Provisions:**

*Properties:*

- **P5** — `runtime` — `human` — flag preserves old API.
  - Invariant: flag off response has no `state_allocations` key.
  - Evidence: [`test_api_hides_allocations_when_flag_off`](#test_api_hides_allocations_when_flag_off).
- **P6** — `runtime` — `human` — flag exposes conserved allocations.
  - Invariant: flag on response allocations sum to gross taxable cents.
  - Evidence: [`test_api_returns_conserved_allocations_when_flag_on`](#test_api_returns_conserved_allocations_when_flag_on).

*Edge cases:*

- Acceptance: flag off + multi-state input → old response exactly.
- Acceptance: flag on + zero gross → allocation array present with zero totals.
- Acceptance: validation error → no partial allocation in response.

### Cross-chapter

- D1 integer cents supports D3 service preservation and D4 API conservation.
- P0 is root proof for P3 and P6.

---

## Contracts

### Inputs / Outputs

```python
@dataclass(frozen=True)
class WorkStateDays:
    state: str
    days: int

@dataclass(frozen=True)
class StateAllocation:
    state: str
    taxable_cents: int
```

### Side effects

- ⚠ Payroll API response expands only behind `multi_state_tax_allocation`.
- ⚠ Tax service emits more state withholding lines when flag enabled.

═══════════════ TRUST BOUNDARY — reviewer stops here ═══════════════

## Implementation tracks

### Track 1: Allocation engine and tax service

**Depends on:** none.

**Constraints:**

- No floats.
- Residual deterministic.
- Allocation reads → selector only.
- Keep flag-off path resident-only.

**Code:**

#### Modify tax/allocation.py lines 1-34

```diff
@@ allocate_taxable_wages (tax/allocation.py:1-34) @@
+def allocate_taxable_wages(gross_cents, work_days):
+    total_days = sum(day.days for day in work_days)
+    if total_days <= 0:
+        raise ValueError("work days required")
+    shares = []
+    for day in merge_by_state(work_days):
+        raw = gross_cents * day.days
+        cents = raw // total_days
+        remainder = raw % total_days
+        shares.append((day.state, cents, remainder))
+    leftover = gross_cents - sum(cents for _, cents, _ in shares)
+    for state in sorted(shares, key=lambda row: (-row[2], row[0]))[:leftover]:
+        add_cent(state)
+    return to_allocations(shares)
```

#### Modify payroll/tax_service.py lines 1-18

```diff
@@ imports + state_taxable_wages (payroll/tax_service.py:1-18) @@
+from tax.allocation import allocate_taxable_wages
 from tax.residency import resident_taxable_wages

 def state_taxable_wages(run, flags):
+    if flags.enabled("multi_state_tax_allocation"):
+        return allocate_taxable_wages(run.gross_taxable_cents, run.work_state_days)
     return resident_taxable_wages(run)
```

**Tests:**

#### `test_allocation_conserves_cents`

*Hypothesis property*. Proves P0.

- In: gross cents `0..1_000_000`; non-empty work-day list; states unique.
- Assert: `sum(a.taxable_cents for a in result) == gross_cents`.

#### `test_allocation_never_negative`

*Hypothesis property*. Proves P1.

- In: gross cents `0..1_000_000`; days `0..365`; at least one positive total.
- Assert: every allocation `>= 0`.

#### `test_residual_uses_largest_remainder`

*Parametrized*. Proves P2.

- In: `gross_cents=100000`; `CA=1 day`; `NY=2 days`.
- Assert: total conserved; extra cent assigned by largest remainder and state-code tie-break.

#### `test_tax_service_uses_allocator`

*Unit*. Proves P3.

- In: run with `CA=5`, `NY=5`; flag enabled; allocator spy.
- Assert: tax service calls allocator once; taxable total equals gross.

#### `test_tax_service_has_no_ratio_math`

*Static*. Proves P4.

- In: source text for `payroll/tax_service.py`.
- Assert: imports `allocate_taxable_wages`; no `days / total_days` or `gross * days` pattern.

**Verify:**

```bash
pytest tests/test_tax_allocation.py tests/test_tax_service.py
```

**Green when:**

- `test_allocation_conserves_cents` green.
- `test_allocation_never_negative` green.
- `test_residual_uses_largest_remainder` green.
- `test_tax_service_uses_allocator` green.
- `test_tax_service_has_no_ratio_math` green.

### Track 2: API response and rollout tests

**Depends on:** Track 1.

**Constraints:**

- Flag off preserves old response exactly.
- Flag on includes allocation array.
- API response uses selector output; no recompute.

**Code:**

#### Modify api/responses.py lines 20-38

```diff
@@ payroll_response (api/responses.py:20-38) @@
 def payroll_response(run, flags):
     payload = base_payroll_response(run)
+    if flags.enabled("multi_state_tax_allocation"):
+        payload["state_allocations"] = [
+            {"state": row.state, "taxable_cents": row.taxable_cents}
+            for row in run.state_allocations
+        ]
     return payload
```

#### New file tests/test_tax_api.py

```python
# API allocation tests live here. Each test cites P5 or P6.
```

**Tests:**

#### `test_api_hides_allocations_when_flag_off`

*Snapshot*. Proves P5.

- In: multi-state payroll run; flag disabled.
- Assert: response equals old snapshot; no `state_allocations` key.

#### `test_api_returns_conserved_allocations_when_flag_on`

*Component*. Proves P6.

- In: multi-state payroll run; flag enabled.
- Assert: `state_allocations` present; sum taxable cents equals gross taxable cents.

**Verify:**

```bash
pytest tests/test_tax_api.py tests/test_tax_allocation.py tests/test_tax_service.py
```

**Green when:**

- `test_api_hides_allocations_when_flag_off` green.
- `test_api_returns_conserved_allocations_when_flag_on` green.
- Track 1 tests still green.

## Verification evidence

### Verifier packet

- Strategy: `CORRECTNESS`.
- Test files:
  - `tests/test_tax_allocation.py`
  - `tests/test_tax_service.py`
  - `tests/test_tax_api.py`
- Each test cites its provision in a docstring/comment.
- Verifier extracts cited IDs; confirms every chapter provision has at least one citing test.
- Verifier constraints: fresh subagent; chapter provisions + test files only; no implementation code.

### Mutation candidates

- Drop residual cent → P0 fails.
- Sort residual ascending → P2 fails.
- Recompute ratio in tax service → P4 fails.
- Always include API key → P5 fails.
- Flag on returns resident total only → P6 fails.

### Static-proof gaps

- Static no-ratio check can miss helper indirection.
- API snapshot cannot prove tax correctness; allocation properties do.

## Verification Gate

- Status: pending
- Last run: never
- Verdict: pending
- Blocking issues: none yet

## Acceptance gate

- [ ] Track 1 green — allocation + service tests pass.
- [ ] Track 2 green — API rollout tests pass.
- [ ] Every chapter provision has at least one citing test.
- [ ] Flag-off API snapshot unchanged.
- [ ] No float math in allocation path.

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
- Next Step: reviewer reads chapters top-down, marks `R> APPROVED`
- Open Questions: none
- Verification Gate: pending
- Files in Play: `.spine/features/multi-state-tax-allocation/plan.md`

### Agent self-review

(Filled after implementation completes.)

- Hardest: residual-cent proof.
- Least confident: static no-ratio heuristic.
- Deviations: none yet.
````
