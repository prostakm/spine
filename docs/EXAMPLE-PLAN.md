# Example Plans

## CORRECTNESS Example

```markdown
# Feature: payroll-rounding

## Context
- Project: `.spine/project.md`
- Conventions: `.spine/conventions.md`
- Progress: `.spine/progress.md`
- Spec: `.spine/features/payroll-rounding/spec.md`

**Status:** REVIEW
**Scope:** Correct net-pay rounding for hourly payroll exports
**Risk:** MEDIUM - touches money math
**Strategy:** CORRECTNESS

## Decisions
**Goal:** Net pay matches finance rules for every supported timesheet
**Approach:** Centralize rounding in one calculator and prove with fixtures + properties
| Alternative | Why rejected |
|---|---|
| Round per intermediate field | drifts from finance worksheet |
**Risks:**
- rule mismatch -> lock fixture table from finance examples

### D1: Rounding mode
**Chosen:** banker rounding at final net-pay step
**Over:** half-up per component - disagrees with worksheet
**Consequence:** all callers must use shared calculator

## Spec + proof
### Rules
**R1: Final-only rounding** - round once after tax and benefit totals
| Input | Condition | Expected |
|-------|-----------|----------|
| 40h @ 25.125 | no deductions | 1005.00 |
| 12h @ 19.995 | fixed tax 10% | 215.95 |

### Properties
<!-- AUTHOR: human -->
- **P1:** range: net pay is never negative
- **P2:** relational: increasing hours never decreases net pay (rate and deductions held constant)
- **P3:** stability: equivalent decimal inputs normalize to same cents value
- **P4:** range: deductions never produce net pay below zero (floor at 0)

### Snapshot anchors
- CSV export row for payroll summary

### Edge cases
- zero-hour timesheet
- deductions larger than gross

## Contracts
### Inputs
```text
calculate_net_pay(hours: Decimal, rate: Decimal, deductions: list[Decimal]) -> Money
```
### Outputs
```text
Money(cents: int, currency: str)
```
### Side effects
- none

<!-- TRUST BOUNDARY - reviewer stops here -->

## Agent instructions
### File manifest
| Action | Path | Notes |
|--------|------|-------|
| MODIFY | `payroll/calculator.py` | shared rounding logic |
| MODIFY | `tests/test_payroll.py` | fixtures + properties |

### Implementation strategy
1. Add failing fixture tests for D1
2. Move rounding to final return path only
3. Add property coverage for monotonicity and non-negative output

### Test implementation notes
- parametrize finance worksheet cases
- use decimal strategies with two to four fractional places

### Acceptance gate
- [ ] Property tests implemented (hypothesis with Decimal strategies)
- [ ] All 4 properties pass for 500 generated cases
- [ ] Finance fixture tests pass unchanged
- [ ] No property statements modified from plan
```

## STRUCTURAL Example

```markdown
# Feature: admin-audit-endpoint

## Context
- Project: `.spine/project.md`
- Conventions: `.spine/conventions.md`
- Progress: `.spine/progress.md`
- Spec: `.spine/features/admin-audit-endpoint/spec.md`

**Status:** REVIEW
**Scope:** Add admin-only audit-log read endpoint
**Risk:** LOW - additive API surface
**Strategy:** STRUCTURAL

## Decisions
**Goal:** Admins can query recent audit events without direct DB access
**Approach:** Add a thin HTTP endpoint over existing audit service
| Alternative | Why rejected |
|---|---|
| expose raw table query | bypasses auth and response shaping |
**Risks:**
- permission leak -> enforce admin check at route boundary

### D1: Authorization boundary
**Chosen:** route-level admin middleware
**Over:** handler-local role check - easier to miss on reuse
**Consequence:** all future admin audit routes reuse same guard

## Spec + proof
### Architecture constraints
- no handler may import storage directly
- admin auth enforced before handler executes

### Boundary behavior
| Request / input | Expected |
|-----------------|----------|
| valid admin token | 200 + JSON list |
| missing auth | 401 |
| non-admin user | 403 |

### Smoke tests
- route exists in API registry
- endpoint calls audit service, not repository

### Properties
<!-- AUTHOR: human -->
- **P1:** structural: no handler callable without admin middleware in call chain
- **P2:** range: response always contains "events" key with list value
- **P3:** structural: handler depends on audit service interface, not repository

## Contracts
### Inputs
```text
GET /admin/audit?limit=int
```
### Outputs
```text
200 {"events": AuditEvent[]}
```
### Side effects
- none

<!-- TRUST BOUNDARY - reviewer stops here -->

## Agent instructions
### File manifest
| Action | Path | Notes |
|--------|------|-------|
| MODIFY | `internal/api/routes.go` | register route + middleware |
| CREATE | `internal/api/admin_audit.go` | handler |
| MODIFY | `internal/api/admin_audit_test.go` | boundary coverage |

### Implementation strategy
1. Add structural tests for route wiring and admin guard
2. Implement handler against existing audit service interface
3. Verify 401/403/200 behavior and JSON shape

### Test implementation notes
- assert handler dependency is service interface
- keep response snapshot small and stable

### Acceptance gate
- [ ] Structural property tests pass (import/dependency assertions)
- [ ] Unauthorized requests return 401/403 as specified
- [ ] Route wiring smoke tests pass
- [ ] No property statements modified from plan
```
