# Example Plans

## CORRECTNESS Example

```markdown
# Feature: payroll-rounding

## Context
- Project: `.spine/project.md`
- Conventions: `.spine/conventions.md`
- Progress: `.spine/progress.md`
- Spec: `.spine/features/payroll-rounding/spec.md`

## Resume
- Source: plan
- Phase: review
- Gate: pending
- Current Slice: validate proof artifacts for payroll rounding
- Next Step: address inline `> [R]:` comments and collect approval
- Open Questions: none
- Files in Play: `.spine/features/payroll-rounding/plan.md`

**Status:** REVIEW
**Scope:** Correct net-pay rounding for hourly payroll exports
**Risk:** MEDIUM — touches money math
**Strategy:** CORRECTNESS
**Budget:** ~8 min

## Decisions

**Goal:** Net pay matches finance rules for every supported timesheet
**Approach:** Centralize rounding in one calculator, prove with fixtures + properties
**Risks:** rule mismatch → lock fixture table from finance examples

### 🔴 D1: Rounding mode

**Chose:** banker rounding at final net-pay step
**Over:** half-up per component — disagrees with finance worksheet
**Locks:** all callers must use shared calculator
**Covered by:** P1, P2, P3

> ANNOTATION:

## Spec + proof

### Rules

**R1: Final-only rounding** — round once after tax and benefit totals

```text
40h × $25.125, no deductions              → $1,005.00
12h × $19.995, flat 10% tax, no deductions → $215.95
 0h × $25.00, no deductions                → $0.00
```

```yaml
case: deductions exceed gross
when:
  hours: 8
  rate: 15.00
  deductions: [200.00]
  tax_mode: none
then:
  net_pay: 0.00  # floor at zero, never negative
```

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

### Logic sketch (optional — procedural decisions only)

```text
calculate_net_pay(hours, rate, deductions) -> Money:
  gross = hours * rate
  net = max(gross - tax_total - sum(deductions), Decimal("0"))
  return Money.from_decimal(
    net.quantize(CENTS, rounding=ROUND_HALF_EVEN)
  )
  # NOT THIS: round(gross) - round(tax) - round(ded)
  # THIS:     round(gross - tax - ded) once at end
```

## Contracts

### Data flow

```text
timesheet → calculator → payroll summary row
```

### Inputs

```text
hours: Decimal       # >= 0
rate: Decimal        # > 0
deductions: list[Decimal]  # each >= 0
```

### Outputs

```text
Money(cents: int, currency: str)
```

### Side effects

- none

<!-- TRUST BOUNDARY — reviewer stops here -->

## Agent instructions

### File manifest

- `MODIFY payroll/calculator.py`
  - symbols: `calculate_net_pay`, `Money.from_decimal`
  - change: move rounding to final return path only
- `MODIFY tests/test_payroll.py`
  - symbols: `test_calculate_net_pay_fixtures`, `test_net_pay_properties`
  - change: add worksheet fixtures and property coverage

### Implementation strategy

1. `tests/test_payroll.py` — Add failing fixture tests per D1

   ```text
   @pytest.mark.parametrize with R1 fixture data
   assert calculate_net_pay(...).cents == expected
   ```

2. `payroll/calculator.py` — Move rounding to final return path

   ```text
   ...existing imports and setup...
   gross = hours * rate
   net = max(gross - tax_total - sum(deductions), Decimal("0"))
   return Money.from_decimal(
     net.quantize(CENTS, rounding=ROUND_HALF_EVEN)  # ← D1
   )
   ```

3. `tests/test_payroll.py` — Add property coverage

   ```text
   @given(hours=decimals(0, 999), rate=decimals(0.01, 999))
   def test_net_pay_never_negative:
     assert calculate_net_pay(...).cents >= 0
   ```

### Test implementation notes

- parametrize finance worksheet cases from R1
- use Decimal strategies with 2-4 fractional places
- add `test_calculate_net_pay_fixtures` and `test_net_pay_never_negative`

### Acceptance gate

- [ ] Property tests implemented (hypothesis with Decimal strategies)
- [ ] All 4 properties pass for 500 generated cases
- [ ] Finance fixture tests pass unchanged
- [ ] No property statements modified from plan

### Agent self-review (fill after implementation)

- Hardest: handling zero-floor when deductions exceed gross — needed explicit max() before rounding
- Least confident: P3 stability — decimal normalization edge cases with trailing zeros
- Deviations: none

## Decisions log

## Errors

## Review Gate
- Status: pending

## State
- Phase: review
```

## STRUCTURAL Example

```markdown
# Feature: admin-audit-endpoint

## Context
- Project: `.spine/project.md`
- Conventions: `.spine/conventions.md`
- Progress: `.spine/progress.md`
- Spec: `.spine/features/admin-audit-endpoint/spec.md`

## Resume
- Source: plan
- Phase: implementation
- Gate: approved
- Current Slice: wire the route and prove the admin boundary
- Next Step: implement handler against audit service interface
- Open Questions: none
- Files in Play: `.spine/features/admin-audit-endpoint/plan.md`

**Status:** REVIEW
**Scope:** Add admin-only audit-log read endpoint
**Risk:** LOW — additive API surface
**Strategy:** STRUCTURAL
**Budget:** ~5 min

## Decisions

**Goal:** Admins can query recent audit events without direct DB access
**Approach:** Thin HTTP endpoint over existing audit service
**Risks:** permission leak → enforce admin check at route boundary

### 🔴 D1: Authorization boundary

**Chose:** route-level admin middleware
**Over:** handler-local role check — easier to miss on reuse
**Locks:** all future admin audit routes reuse same guard
**Covered by:** P1, boundary behavior tests

> ANNOTATION:

## Spec + proof

### Architecture constraints

- no handler may import storage directly
- admin auth enforced before handler executes

### Boundary behavior

```text
GET /admin/audit?limit=int:
  admin token    → 200 {"events": [...]}
  no auth        → 401
  non-admin      → 403
```

### Smoke tests

- route exists in API registry
- endpoint calls audit service, not repository

### Properties
<!-- AUTHOR: human -->
- **P1:** structural: no handler callable without admin middleware in call chain
- **P2:** range: response always contains "events" key with list value
- **P3:** structural: handler depends on audit service interface, not repository

## Contracts

### Data flow

```text
request → admin middleware → handler → audit service → response
```

### Inputs

```text
limit: int  # 1-100, default 20
```

### Outputs

```text
events: AuditEvent[]  # sorted by timestamp desc
```

### Side effects

- none

<!-- TRUST BOUNDARY — reviewer stops here -->

## Agent instructions

### File manifest

- `MODIFY internal/api/routes.go`
  - symbols: `registerRoutes`, `requireAdmin`
  - change: register `/admin/audit` behind admin middleware
- `CREATE internal/api/admin_audit.go`
  - symbols: `AdminAuditHandler`, `AdminAuditService`
  - change: handler depends on audit service interface only
- `CREATE internal/api/admin_audit_test.go`
  - symbols: `TestAdminAuditAuth`, `TestAdminAuditShape`
  - change: cover 401/403/200 and dependency boundary

### Implementation strategy

1. `internal/api/admin_audit_test.go` — Structural tests first

   ```text
   TestAdminAuditAuth:
     ...setup test server with middleware...
     no auth   → assert 401
     non-admin → assert 403
     admin     → assert reaches handler  # ← D1
   ```

2. `internal/api/admin_audit.go` — Handler against interface

   ```text
   type AdminAuditService interface {
     ListRecent(ctx, limit int) ([]AuditEvent, error)
   }
   # handler takes AdminAuditService, NOT AuditRepository
   # P3 enforced by this interface dependency
   ```

3. `internal/api/routes.go` — Wire behind admin middleware

   ```text
   admin.GET("/audit", requireAdmin(AdminAuditHandler(svc)))
   ```

### Test implementation notes

- assert handler dependency is service interface (P3)
- keep response snapshot small and stable
- add `TestAdminAuditAuth` and `TestAdminAuditShape`

### Acceptance gate

- [ ] Structural property tests pass (import/dependency assertions)
- [ ] Unauthorized requests return 401/403 as specified
- [ ] Route wiring smoke tests pass
- [ ] No property statements modified from plan

### Agent self-review (fill after implementation)

- Hardest: ensuring interface boundary — Go doesn't enforce without deliberate design
- Least confident: smoke test for route registry — need to check how test framework exposes routes
- Deviations: none

## Decisions log

## Errors

## Review Gate
- Status: approved

## State
- Phase: implementation
```
