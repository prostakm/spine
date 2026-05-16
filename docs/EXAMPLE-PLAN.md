# Example Plan

````markdown
# Feature: archive-payroll-runs

> **Story:**
> Payroll admins need retire old draft runs without deleting audit history.
> Current list grows forever and accidental rerun stays one click away.
> Archive action hides stale runs, keeps read-only audit trail.

## Status
- **Status:** REVIEW
- **Strategy:** STRUCTURAL
- **Risk:** MEDIUM — destructive-looking action, audit-sensitive data
- **Scope:** Archive completed or draft payroll runs; hide archived runs by default.

## System view

```text
[UNCHANGED] Admin UI
    │ click Archive / toggle Include archived
    ▼
[M] payroll API ── guard status + auth ──► [M] payroll_runs.archived_at
    │                                      │
    └──────── list query filters ◄────────┘
[NEW] audit event on first archive only
```

## Behaviors

- Flow A — archive a run (write path)
- Flow B — list runs (read path)

System-wide invariants:

- **P1** — archived run remains auditable
  - holds: DB row + audit event
  - test: `test_archive_preserves_run_and_writes_audit`
  - never: delete `payroll_runs` row
  - never: redact existing totals
- **P2** — archive idempotent
  - holds: archive endpoint
  - test: `test_archive_idempotent`
  - never: rewrite `archived_at` on second call
  - never: emit duplicate audit events

## Flow A — archive a run

```text
UI action → POST /payroll-runs/:id/archive → auth/status guards
          → UPDATE archived_at WHERE archived_at IS NULL
          → emit audit once → return archived run
```

### A.1 — Request accepted and guarded

> **Step intent:** Validate caller and run status before any write. Running runs stay protected.

- 🔴 **D1** — archive as soft delete
  <details><summary>chose: nullable `archived_at`</summary>

  - over: `is_archived` boolean
  - why not: loses ordering, loses audit timestamp
  - consequence: all active queries filter `archived_at IS NULL`
  </details>

- **R1** — only payroll admins archive runs
  - holds: API guard
  - test: `test_archive_requires_payroll_admin`
  - must not: allow employee self-service token

- **R2** — running run cannot archive
  - holds: API guard
  - test: `test_archive_rejects_running_run`
  - never: archive run with status `processing`

- → impl: [I2](#i2), [I3](#i3)

### A.2 — Archive write commits once

> **Step intent:** Set the timestamp once, then treat repeats as successful no-ops.

- 🔴 **P3** — write is compare-and-set
  - holds: repository update
  - test: `test_archive_idempotent`
  - pattern: `UPDATE ... WHERE archived_at IS NULL`
  - never: update already archived row
  - never: change `updated_at` on no-op retry

- 🟡 **D2** — return current archived row on retry
  <details><summary>chose: 200 with existing archive state</summary>

  - over: 409 conflict
  - why not: retrying clients need safe convergence
  - consequence: endpoint result stable after first success
  </details>

- → impl: [I1](#i1), [I3](#i3), [I7](#i7)

### A.3 — Audit emitted

> **Step intent:** Record who archived the run, but only for the first state change.

- **P4** — one audit event per archive transition
  - holds: service layer
  - test: `test_archive_preserves_run_and_writes_audit`
  - never: emit audit event on idempotent retry

- → impl: [I3](#i3), [I7](#i7)

## Flow B — list runs

```text
GET /payroll-runs → parse include_archived → query active by default
                  → serialize archived_at → UI badge + toggle
```

### B.1 — Default list hides archived

> **Step intent:** Keep normal payroll work queue clean without losing access to archived history.

- 🟡 **D3** — active-only default
  <details><summary>chose: hide archived unless requested</summary>

  - over: show all with badge
  - why not: old stale runs stay noisy
  - consequence: query param needed for audit view
  </details>

- **P5** — archived excluded by default
  - holds: list repository
  - test: `test_list_excludes_archived_by_default`
  - never: hide active runs

- → impl: [I4](#i4), [I6](#i6), [I8](#i8)

### B.2 — Audit view includes archived

> **Step intent:** Let admins recover archived run context on demand.

- **R3** — `include_archived=true` returns active and archived
  - holds: API query parser
  - test: `test_list_includes_archived_when_requested`
  - never: require separate endpoint

- **P6** — archived state visible in response
  - holds: serializer + UI
  - test: `test_archived_badge_visible`
  - never: infer archived from status

- → impl: [I4](#i4), [I5](#i5), [I6](#i6), [I8](#i8), [I9](#i9)

## Acceptance matrix

| ID | Invariant / rule | Test | Strategy |
|----|------------------|------|----------|
| P1 | preserve run + audit | `test_archive_preserves_run_and_writes_audit` | STRUCTURAL |
| P2 | idempotent archive | `test_archive_idempotent` | CORRECTNESS |
| R1 | admin only | `test_archive_requires_payroll_admin` | CORRECTNESS |
| R2 | no running archive | `test_archive_rejects_running_run` | CORRECTNESS |
| P5 | default excludes archived | `test_list_excludes_archived_by_default` | STRUCTURAL |
| R3 | include archived param | `test_list_includes_archived_when_requested` | STRUCTURAL |
| P6 | response/UI exposes archived | `test_archived_badge_visible` | STRUCTURAL |

---

<!-- ═══════════════════════════════════════════════════════ -->
<!-- TRUST BOUNDARY — reviewer stops here                   -->
<!-- ═══════════════════════════════════════════════════════ -->

## Agent instructions

### Verification packet

- Strategy: `STRUCTURAL`
- Properties: `P1, P2, P3, P4, P5, P6`
- Rules: `R1, R2, R3`
- Verifier constraints: fresh subagent; judge from migration, API tests, UI tests.

### File manifest

```text
payroll/
├── db/migrations/20260429_add_archived_at.sql        [C] → I1
├── api/payroll_runs.py                               [M] → I2, I4
├── services/payroll_runs.py                          [M] → I3
├── repositories/payroll_runs.py                      [M] → I3, I4
├── serializers/payroll_runs.py                       [M] → I5
├── web/payroll/RunList.tsx                           [M] → I6
└── tests/
    ├── test_archive_payroll_runs.py                  [C] → I7
    ├── test_list_payroll_runs.py                     [C] → I8
    └── RunList.test.tsx                              [C] → I9
```

### Implementation

#### I1 — add archive timestamp <a id="i1"></a>

- **Intent:** Add nullable archive timestamp and index active run lookup.
- **References:** D1, P1, P3
- **Critical:** 🔴

```diff
--- /dev/null
+++ b/payroll/db/migrations/20260429_add_archived_at.sql
@@ -0,0 +1,3 @@
+ALTER TABLE payroll_runs ADD COLUMN archived_at TIMESTAMPTZ NULL;
+CREATE INDEX payroll_runs_active_idx
+  ON payroll_runs(company_id, pay_date) WHERE archived_at IS NULL;
```

#### I2 — add archive route guard <a id="i2"></a>

- **Intent:** Route archive requests through admin and status guards.
- **References:** R1, R2
- **Critical:** 🔴

```diff
--- a/payroll/api/payroll_runs.py
+++ b/payroll/api/payroll_runs.py
@@ -22,6 +22,14 @@ def get_run(run_id):
     return serialize_run(service.get_run(run_id))
+
+@router.post("/payroll-runs/{run_id}/archive")
+def archive_run(run_id, user=Depends(require_payroll_admin)):
+    run = service.get_run(run_id)
+    if run.status == "processing":
+        raise HTTPException(status_code=409, detail="processing run cannot be archived")
+    return serialize_run(service.archive_run(run_id, user.id))
```

#### I3 — archive service compare-and-set <a id="i3"></a>

- **Intent:** Archive once, return current row on repeat, emit audit only on transition.
- **References:** D2, P2, P3, P4
- **Critical:** 🔴

```diff
--- a/payroll/services/payroll_runs.py
+++ b/payroll/services/payroll_runs.py
@@ -41,6 +41,13 @@ def list_runs(company_id):
     return repo.list_runs(company_id)
+
+def archive_run(run_id, actor_id):
+    archived = repo.archive_once(run_id)
+    run = repo.get_run(run_id)
+    if archived:
+        audit.emit("payroll_run.archived", actor_id=actor_id, run_id=run_id)
+    return run
--- a/payroll/repositories/payroll_runs.py
+++ b/payroll/repositories/payroll_runs.py
@@ -55,6 +55,13 @@ def get_run(run_id):
     return db.fetch_one("SELECT * FROM payroll_runs WHERE id = :id", {"id": run_id})
+
+def archive_once(run_id):
+    result = db.execute("""
+        UPDATE payroll_runs SET archived_at = now()
+        WHERE id = :id AND archived_at IS NULL
+    """, {"id": run_id})
+    return result.rowcount == 1
```

#### I4 — list query archive filter <a id="i4"></a>

- **Intent:** Hide archived rows by default; include them when explicitly requested.
- **References:** D3, P5, R3

```diff
--- a/payroll/api/payroll_runs.py
+++ b/payroll/api/payroll_runs.py
@@ -10,7 +10,8 @@ router = APIRouter()
-@router.get("/payroll-runs")
-def list_runs(company_id=Depends(current_company_id)):
-    return [serialize_run(run) for run in service.list_runs(company_id)]
+@router.get("/payroll-runs")
+def list_runs(company_id=Depends(current_company_id), include_archived: bool = False):
+    return [serialize_run(run) for run in service.list_runs(company_id, include_archived)]
--- a/payroll/repositories/payroll_runs.py
+++ b/payroll/repositories/payroll_runs.py
@@ -11,7 +11,10 @@ def list_runs(company_id):
-    return db.fetch_all("SELECT * FROM payroll_runs WHERE company_id = :company_id", params)
+    where = "company_id = :company_id"
+    if not include_archived:
+        where += " AND archived_at IS NULL"
+    return db.fetch_all(f"SELECT * FROM payroll_runs WHERE {where}", params)
```

#### I5 — serialize archived state <a id="i5"></a>

- **Intent:** Expose archive timestamp so clients do not infer from status.
- **References:** P6

```diff
--- a/payroll/serializers/payroll_runs.py
+++ b/payroll/serializers/payroll_runs.py
@@ -8,6 +8,7 @@ def serialize_run(run):
         "id": run.id,
         "status": run.status,
         "pay_date": run.pay_date.isoformat(),
+        "archived_at": run.archived_at.isoformat() if run.archived_at else None,
     }
```

#### I6 — UI archive controls <a id="i6"></a>

- **Intent:** Add archive action, archived badge, and include-archived toggle.
- **References:** D3, P6

```diff
--- a/payroll/web/payroll/RunList.tsx
+++ b/payroll/web/payroll/RunList.tsx
@@ -12,6 +12,9 @@ export function RunList() {
   return <section>
+    <label><input type="checkbox" onChange={toggleArchived} /> Include archived</label>
     {runs.map(run => <article key={run.id}>
+      {run.archived_at && <span>Archived</span>}
       <span>{run.status}</span>
+      {!run.archived_at && <button onClick={() => archiveRun(run.id)}>Archive</button>}
     </article>)}
   </section>
```

#### I7 — archive endpoint tests <a id="i7"></a>

- **Intent:** Prove guards, idempotency, preservation, and audit behavior.
- **References:** P1, P2, P3, P4, R1, R2
- **Critical:** 🔴

```diff
--- /dev/null
+++ b/payroll/tests/test_archive_payroll_runs.py
@@ -0,0 +1,5 @@
+def test_archive_requires_payroll_admin(): pass
+def test_archive_rejects_running_run(): pass
+def test_archive_idempotent(): pass
+def test_archive_preserves_run_and_writes_audit(): pass
```

#### I8 — list archive tests <a id="i8"></a>

- **Intent:** Prove default active-only list and explicit audit view.
- **References:** P5, R3

```diff
--- /dev/null
+++ b/payroll/tests/test_list_payroll_runs.py
@@ -0,0 +1,3 @@
+def test_list_excludes_archived_by_default(): pass
+def test_list_includes_archived_when_requested(): pass
```

#### I9 — UI archive badge test <a id="i9"></a>

- **Intent:** Prove archived state visible and controls not shown for archived rows.
- **References:** P6

```diff
--- /dev/null
+++ b/payroll/tests/RunList.test.tsx
@@ -0,0 +1,2 @@
+it("test_archived_badge_visible", () => {})
```

### Acceptance gate

- [ ] `pytest payroll/tests/test_archive_payroll_runs.py payroll/tests/test_list_payroll_runs.py` passes
- [ ] `npm test -- RunList.test.tsx` passes
- [ ] Properties `P1..P6` hold
- [ ] Rules `R1..R3` hold

### Agent self-review (fill after implementation)

- Hardest: ___
- Least confident: ___
- Deviations from plan: ___

---

## Decisions log
- 2026-04-29 — soft-delete archive — preserve audit history and retry safety

## Errors
- none — attempt: none — resolution: none

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
- Current Slice: example plan ready for review
- Next Step: use as canonical reference for new flow-aligned plans
- Open Questions: none
- Files in Play: docs/EXAMPLE-PLAN.md

## State
- Phase: planning
- Verification Gate: pending
````
