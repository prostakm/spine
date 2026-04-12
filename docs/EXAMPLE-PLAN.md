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
**Rejected options (only if informative):**
- Round per intermediate field - drifts from finance worksheet
**Key risks (only if non-obvious):**
- rule mismatch -> lock fixture table from finance examples

### D1: Rounding mode
**Chosen:** banker rounding at final net-pay step
**Over:** half-up per component - disagrees with worksheet
**Consequence:** all callers must use shared calculator

## Spec + proof
### Rules
**R1: Final-only rounding** - round once after tax and benefit totals
```text
when: hours=40, rate=25.125, deductions=[]
then: net_pay=1005.00
when: hours=12, rate=19.995, tax_mode=flat_10, deductions=[]
then: net_pay=215.95
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
- `MODIFY payroll/calculator.py`
  - symbols: `calculate_net_pay`, `Money.from_decimal`
  - change: move rounding to final return path only
- `MODIFY tests/test_payroll.py`
  - symbols: `test_calculate_net_pay_fixtures`, `test_net_pay_properties`
  - change: add worksheet fixtures and property coverage

### Implementation strategy
1. `tests/test_payroll.py` - Add failing fixture tests for D1

   ```python
   @pytest.mark.parametrize("hours, rate, deductions, expected", [...])
   def test_calculate_net_pay_fixtures(...):
       assert calculate_net_pay(...).cents == expected
   ```

2. `payroll/calculator.py` - Move rounding to final return path only

   ```python
   gross = hours * rate
   net = max(gross - tax_total - deduction_total, Decimal("0"))
   return Money.from_decimal(net.quantize(CENTS, rounding=ROUND_HALF_EVEN))
   ```

3. `tests/test_payroll.py` - Add property coverage for monotonicity and non-negative output

   ```python
   @given(hours=..., rate=..., deductions=...)
   def test_net_pay_never_negative(...):
       assert calculate_net_pay(...).cents >= 0
   ```

### Test implementation notes
- parametrize finance worksheet cases
- use decimal strategies with two to four fractional places
- add `test_calculate_net_pay_fixtures` and `test_net_pay_never_negative`

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
**Rejected options (only if informative):**
- expose raw table query - bypasses auth and response shaping
**Key risks (only if non-obvious):**
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
- `when: GET /admin/audit?limit=20 + admin token -> then: 200 {"events": [...]}`
- `when: GET /admin/audit?limit=20 + no auth -> then: 401`
- `when: GET /admin/audit?limit=20 + non-admin token -> then: 403`

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
- `MODIFY internal/api/routes.go`
  - symbols: `registerRoutes`, `requireAdmin`
  - change: register `/admin/audit` behind admin middleware
- `CREATE internal/api/admin_audit.go`
  - symbols: `AdminAuditHandler`, `AdminAuditService`
  - change: add handler that depends on audit service interface only
- `MODIFY internal/api/admin_audit_test.go`
  - symbols: `TestAdminAuditAuth`, `TestAdminAuditShape`
  - change: cover 401/403/200 and dependency boundary

### Implementation strategy
1. `internal/api/admin_audit_test.go` - Add structural tests for route wiring and admin guard

   ```go
   func TestAdminAuditAuth(t *testing.T) {
       // no auth -> 401
       // non-admin -> 403
       // admin -> reaches handler
   }
   ```

2. `internal/api/admin_audit.go` - Implement handler against existing audit service interface

   ```go
   type AdminAuditService interface {
       ListRecent(ctx context.Context, limit int) ([]AuditEvent, error)
   }
   ```

3. `internal/api/routes.go` - Wire route and verify JSON shape

   ```go
   admin.GET("/audit", requireAdmin(AdminAuditHandler(service)))
   ```

### Test implementation notes
- assert handler dependency is service interface
- keep response snapshot small and stable
- add `TestAdminAuditAuth` and `TestAdminAuditShape`

### Acceptance gate
- [ ] Structural property tests pass (import/dependency assertions)
- [ ] Unauthorized requests return 401/403 as specified
- [ ] Route wiring smoke tests pass
- [ ] No property statements modified from plan
```
