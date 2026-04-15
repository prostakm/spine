# Example Plans

## CORRECTNESS Example

```markdown
# Feature: payroll-rounding

## Context
- Project: `.spine/project.md`
- Conventions: `.spine/conventions.md`
- Progress: `.spine/progress.md`
- Spec: `.spine/features/payroll-rounding/spec.md`
- User context: finance export rounds net pay incorrectly
- Existing behavior: components round independently before final net pay
- Scope choice: fix net-pay math only
- Dependency notes: payroll CSV snapshot must stay stable

**Status:** REVIEW
**Scope:** Correct net-pay rounding for hourly payroll exports
**Risk:** MEDIUM - touches money math
**Strategy:** CORRECTNESS
**Budget:** ~8 min

## Decisions

- Goal: **net pay** matches finance rules for every supported timesheet
- Approach: centralize rounding in one calculator, then prove it with fixtures and properties
- Risk: rule mismatch -> lock fixture cases from finance worksheet examples

### 🔴 D1: Final-only rounding

- Chose: banker rounding at the final net-pay step
- Over: per-component half-up rounding - disagrees with finance worksheet
- Locks: all callers use one shared calculator
- Covered by: P1, P2, P3
- Poka-yoke later: shared `Money` helper

> ANNOTATION:

## Spec + proof

### Rules

**R1: Final-only rounding** - round once after tax and benefit totals

```text
40h × $25.125, no deductions                -> $1,005.00
12h × $19.995, flat 10% tax, no deductions  -> $215.95
0h × $25.00, no deductions                  -> $0.00
```

```yaml
case: deductions exceed gross
when:
  hours: 8
  rate: 15.00
  deductions: [200.00]
  tax_mode: none
then:
  net_pay: 0.00
```

### Properties
<!-- AUTHOR: human -->
- **P1:** range: net pay is never negative
- **P2:** relational: increasing hours never decreases net pay
- **P3:** stability: equivalent decimal inputs normalize to the same cents

### Snapshot anchors

- payroll summary CSV row

### Edge cases

- zero-hour timesheet
- deductions larger than gross

### Code sketch (optional)

```text
calculate_net_pay(hours, rate, deductions) -> Money:
  gross = hours * rate
  net = max(gross - tax_total - sum(deductions), Decimal("0"))
  return Money.from_decimal(net.quantize(CENTS, rounding=ROUND_HALF_EVEN))
```

## Contracts

### Data flow

```text
timesheet -> calculator -> payroll summary row
```

### Inputs

```text
hours: Decimal  # >= 0
rate: Decimal  # > 0
deductions: list[Decimal]  # each >= 0
```

### Outputs

```text
Money(cents: int, currency: str)
```

### Side effects

- none

<!-- TRUST BOUNDARY - reviewer stops here -->

## Agent instructions

### Applied constraints

- `source: payroll/AGENTS.md` - use the shared `Money` type for public payroll values
- `source: .spine/conventions.md` - keep decimal math centralized in one calculator path

### Codebase packet

This section makes the plan executable without broad re-reading.

#### Current signatures

```text
payroll/calculator.py::calculate_net_pay(hours, rate, deductions) -> Money
tests/test_payroll.py::test_calculate_net_pay_fixtures() -> None
```

#### Local snippets

```text
payroll/calculator.py::calculate_net_pay
  gross = hours * rate
  ...existing tax_total calculation...
  return Money.from_decimal(component_total)
```

#### Test hooks and fixtures

- `finance worksheet fixtures` in `tests/test_payroll.py` - existing fixture style for approved examples
- `Decimal` strategies in `tests/test_payroll.py` - current property-test entry point

#### Generated/runtime names

- `Money.from_decimal` in `payroll/calculator.py` - existing conversion path to preserve

### File manifest

- `MODIFY payroll/calculator.py`
  - symbols: `calculate_net_pay`, `Money.from_decimal`
  - change: move rounding to the final return path only
- `MODIFY tests/test_payroll.py`
  - symbols: `test_calculate_net_pay_fixtures`, `test_net_pay_properties`
  - change: add worksheet fixtures and property coverage

### Implementation strategy

1. `tests/test_payroll.py` - Add failing fixture tests per D1

   ```text
   @pytest.mark.parametrize with R1 fixture data
   assert calculate_net_pay(...).cents == expected
   ```

2. `payroll/calculator.py` - Move rounding to the final return path

   ```text
   gross = hours * rate
   net = max(gross - tax_total - sum(deductions), Decimal("0"))
   return Money.from_decimal(net.quantize(CENTS, rounding=ROUND_HALF_EVEN))
   ```

### Test implementation notes

- parametrize finance worksheet cases from R1
- use Decimal strategies with 2-4 fractional places

### Validation commands

- `pytest tests/test_payroll.py`
- `ruff check payroll tests`

### Acceptance gate

- [ ] Property tests implemented
- [ ] All 3 properties pass for 500 generated cases
- [ ] Finance fixture tests pass unchanged

### Agent self-review (fill after implementation)

- Hardest: zero-floor handling before rounding
- Least confident: decimal normalization edge cases with trailing zeros
- Deviations: none

## Decisions log

## Errors

## Review Gate
- Status: pending

## Resume
- Source: plan
- Phase: review
- Gate: pending
- Current Slice: validate proof artifacts for payroll rounding
- Next Step: address inline `> [R]:` comments and collect approval
- Open Questions: none
- Files in Play: `.spine/features/payroll-rounding/plan.md`

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
- User context: admins need a safe way to inspect recent audit events
- Existing behavior: audit data exists, but no HTTP read boundary exposes it
- Scope choice: add one admin-only read endpoint
- Dependency notes: existing audit service interface stays the data source

**Status:** REVIEW
**Scope:** Add **admin-only** audit-log read endpoint
**Risk:** LOW - additive API surface
**Strategy:** STRUCTURAL
**Budget:** ~5 min

## Decisions

- Goal: admins can query recent audit events without direct DB access
- Approach: thin HTTP endpoint over the existing audit service
- Risk: permission leak -> enforce the admin check at the route boundary

### 🔴 D1: Authorization boundary

- Chose: route-level admin middleware
- Over: handler-local role check - easier to miss on reuse
- Locks: all future admin audit routes reuse the same guard
- Covered by: P1, boundary behavior tests
- Poka-yoke later: shared `requireAdmin` route helper

> ANNOTATION:

## Spec + proof

### Architecture constraints

- no handler imports storage directly
- admin auth runs before the handler executes

### Boundary behavior

```text
GET /admin/audit?limit=int:
  admin token -> 200 {"events": [...]}
  no auth -> 401
  non-admin -> 403
```

### Flow sketch (optional)

```text
request -> admin middleware
is admin:
  yes -> handler -> audit service -> response
  no  -> 401 or 403
```

### Smoke tests

- route exists in API registry
- endpoint calls audit service, not repository

### Properties
<!-- AUTHOR: human -->
- **P1:** structural: no handler is callable without admin middleware
- **P2:** range: response always contains `events` with a list value
- **P3:** structural: handler depends on audit service, not repository

## Contracts

### Data flow

```text
request -> admin middleware -> handler -> audit service -> response
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

<!-- TRUST BOUNDARY - reviewer stops here -->

## Agent instructions

### Applied constraints

- `source: internal/api/AGENTS.md` - admin routes stay behind shared middleware, not handler-local checks
- `source: .spine/conventions.md` - handlers stay thin and depend on interfaces at the boundary

### Codebase packet

This section makes the plan executable without broad re-reading.

#### Current signatures

```text
internal/api/routes.go::registerRoutes(router) -> void
internal/api/routes.go::requireAdmin(next) -> handler
```

#### Local snippets

```text
internal/api/routes.go::registerRoutes
  ...public routes...
  router.GET("/health", healthHandler)
  ...admin group setup nearby...
```

#### Test hooks and fixtures

- `newTestServer` in `internal/api/admin_audit_test.go` - existing route+middleware harness shape
- `fakeAuditService` in `internal/api/admin_audit_test.go` - current dependency-double pattern

#### Generated/runtime names

- `requireAdmin` - exact middleware hook to reuse
- `AdminAuditService` - interface name locked by this plan

### File manifest

- `MODIFY internal/api/routes.go`
  - symbols: `registerRoutes`, `requireAdmin`
  - change: register `/admin/audit` behind admin middleware
- `CREATE internal/api/admin_audit.go`
  - symbols: `AdminAuditHandler`, `AdminAuditService`
  - change: make the handler depend on the audit service interface only

### Implementation strategy

1. `internal/api/admin_audit_test.go` - Structural tests first

   ```text
   no auth -> assert 401
   non-admin -> assert 403
   admin -> assert request reaches handler
   ```

2. `internal/api/admin_audit.go` - Handler against interface

   ```text
   type AdminAuditService interface {
     ListRecent(ctx, limit int) ([]AuditEvent, error)
   }
   ```

3. `internal/api/routes.go` - Wire behind admin middleware

   ```text
   admin.GET("/audit", requireAdmin(AdminAuditHandler(svc)))
   ```

### Test implementation notes

- assert the handler dependency stays at the service boundary
- keep the response snapshot small and stable

### Validation commands

- `go test ./internal/api/...`
- `go test ./...`

### Acceptance gate

- [ ] Structural property tests pass
- [ ] Unauthorized requests return 401 and 403 as specified
- [ ] Route wiring smoke tests pass

### Agent self-review (fill after implementation)

- Hardest: preserving the interface boundary in a language without import guards
- Least confident: route-registry smoke test detail
- Deviations: none

## Decisions log

## Errors

## Review Gate
- Status: approved

## Resume
- Source: plan
- Phase: implementation
- Gate: approved
- Current Slice: wire the route and prove the admin boundary
- Next Step: implement handler against the audit service interface
- Open Questions: none
- Files in Play: `.spine/features/admin-audit-endpoint/plan.md`

## State
- Phase: implementation
```
