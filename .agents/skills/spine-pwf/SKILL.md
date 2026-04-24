---
name: spine-pwf
description: >
  File-based planning workflow. Invoke explicitly with $spine-pwf or
  "use spine" / "spine plan". Does NOT activate automatically.
allow_implicit_invocation: false
---

# Spine PWF

## Gates — stop at each, never auto-advance

```
SPEC (opt) ──► STOP ──► PLAN ──► STOP ──► IMPLEMENT ──► VERIFY ──► REVIEW
               "plan {slug}"    user reviews plan.md
                                inline > [R]: comments
                                marks APPROVED
```

## Setup
1. Read `.spine/project.md`, `.spine/conventions.md`, `.spine/progress.md`
2. Determine slug (kebab-case), write to `.spine/active-feature`
3. Create `.spine/features/{slug}/` from `_template/`
4. Keep `## Resume` current in the active `spec.md` or `plan.md`.
   It is the fresh-session handoff; keep it short, phase-accurate,
   and near the bottom for fast tail-based recovery.

## Planning phase
Use **spine-plan** skill for plan creation.
Planning is complete when `plan.md` passes `.spine/scripts/validate-plan.sh`.
Run that validator before asking for review approval; a pending review gate still
allows explicit validator runs.

### Workflow enforcement
- SessionStart, Stop, and OpenCode review gates are enforced by hooks/plugins
  outside this skill
- Do not work around those guards or treat them as optional
- If a hook or gate blocks progress, fix the workflow state instead of bypassing it
- While the plan gate is pending, only explicit edits to `plan.md` / `spec.md`
  and read-only commands are allowed
- Allowed read-only commands while review is pending include plan-validation
  commands such as `.spine/scripts/validate-plan.sh`, `scripts/validate-plan.sh`,
  and their `./...` variants

## Plan Review (Gate 2)

After creating plan.md:

> "Plan at `.spine/features/{slug}/plan.md`.
> Start with `Changed Surface` and top `Risk`.
> Then review `Decisions`, `Spec + proof`, and `Contracts`.
> Stop at the trust boundary.
> Focus comments on chosen approach, proof cases, and missing risk.
> Mark properties you approve with `> [R]: ✓`.
> Add `> [R]:` comments next to anything you want changed.
> Mark `> [R]: APPROVED` when ready, or say `approved` / `plan approved` in chat.
> Mirror explicit chat approval into `plan.md` before implementation."

Then STOP.

### Inline review protocol
User adds `> [R]:` comments in plan.md, co-located with context:
```
**P1**
  - Invariant: range: net pay is never negative
> [R]: also add: net pay never exceeds gross pay
```

### On "address comments" / "apply review":
1. Find all `> [R]:` lines (not marked ✓)
2. Change requests → revise the plan
3. Questions → answer as `> [A]: response`
4. Mark done: `> [R]: ✓ original`
5. Changes made → STOP for re-review
6. `> [R]: APPROVED` or explicit chat approval mirrored into `plan.md` → proceed

## Implementation (after Gate 2)

### Delegation discipline
- Main thread owns approvals, integration decisions, and final user communication
- Keep trivial edits on the main thread
- If blocked or stuck, escalate to the user rather than spawning additional agents
- Exception: one fresh context-minimized verifier subagent is required after
  the planned evidence passes and before review/completion
- Do not change the workflow shape:
  `spec/brainstorm (optional) -> plan -> approval -> implement -> verify -> review`

### Plan-first execution
- Approved `plan.md` is the implementation source of truth
- Start implementation from the approved plan, not from broad project re-reading
- If the plan already carries the needed constraints and current-state facts,
  do NOT reopen `.spine/project.md`, `.spine/conventions.md`,
  `.spine/progress.md`, `findings.md`, or `log.md`
- First product-code reads after the plan should come from the current step's
  file tree entries
- If implementation needs a fact that is not in the plan
  (signature, snippet, test hook, generated name, repo instruction), STOP and
  patch the plan first rather than rebuilding context ad hoc

### Proof-first sequence
For all strategies: implement the plan's strongest enforcement FIRST, then
production code. Properties in the plan are specifications. Implementation
serves them.

- **Static-enforced properties**: add the type, lint, formatter, or repo script
  rule first when the invariant is structural or source-shaped
- **CORRECTNESS**: write runtime tests from properties and approved fixtures
  first, then implement until tests pass
- **EQUIVALENCE**: capture equivalence anchor before changes, add the lightest
  preservation proof that matches the invariant, then refactor, assert anchor
  holds
- **STRUCTURAL**: implement lint/type/script enforcement first where possible;
  add smoke tests only for runtime wiring or boundary behavior
- **REGRESSION**: write the reproduction check first; if the bug is structural,
  prefer a static rule over a permanent runtime regression test

### Property authorship protection
Properties above the trust boundary are owned by the reviewer.

- **human** / **human-validated**: implement as written. Do not modify.
- **agent-proposed**: implement as written. Not trusted as proof until
  reviewer marks `> [R]: ✓`.
- Property appears wrong → STOP. Propose revision with `> [A]:`.
  Wait for reviewer approval. Do not silently adjust.
- Property is incomplete (missing edge case) → propose an additional
  property, mark it `agent-proposed`. Existing properties stay as-is.

### Property implementation
- For `Enforcement: static`, implement the rule in the strongest practical
  layer: type system, linter/static analysis, formatter, or repo validation
  script
- For `Enforcement: runtime`, use the project's property testing framework
  (Hypothesis, fast-check, jqwik, rapid, FsCheck, QuickCheck, etc.)
- If no property framework exists and runtime properties require one, add it as
  the first implementation step. Note the dependency in findings.md.
- Minimum 100 generated cases per runtime property (exhaustive if domain is
  finite)
- Property test files live alongside but separate from example-based tests
- Preserve traceability: plan property → evidence source (rule, script, or test)

### Coverage verification gate
- After static rules, scripts, and tests pass, extract a verifier packet from
  the approved plan with
  `.spine/scripts/extract-verification-context.sh ".spine/features/{slug}/plan.md"`
- Launch one fresh verifier subagent with only:
  - the extracted verifier packet
  - bounded verification evidence from the plan's `### Verification evidence`
    contract
- Do NOT give the verifier the full `plan.md`, implementation strategy,
  findings.md, or freeform implementation narrative
- Ask the verifier to judge each property as `covered`, `weak`, or `uncovered`
  and list likely surviving runtime mutants for runtime-enforced properties.
  For static-enforced properties, ask for rule/script gaps or plausible
  bypasses instead of mutation-style feedback.
- If the verifier says `failed` or reports weak/uncovered properties, STOP and
  strengthen the rule, script, or test evidence before review
- Update `## Verification Gate` with `passed` or `failed`, last run, verdict,
  and blocking issues before moving on

### Execution rules
1. Work through the implementation strategy sequentially
2. If the approved plan is incomplete or contradicted by the codebase,
   STOP and revise before coding
3. Treat the approved `plan.md` as the startup brief and ongoing handoff;
   keep `## Resume`, acceptance checks, and the implementation packet current
4. **2-Action Rule**: after every 2 view/search/read ops → update findings.md
5. Workflow friction is first-class: if a hook, validator, or review ritual slows
   or blocks progress, record it in findings.md `## Workflow Friction` with the
   trigger, impact, and suggested fix before moving on
6. On each completed step: update acceptance checks, `## Resume`, and log.md;
   every log entry must include `Workflow friction`, even when the value is `none`
7. Before review or completion: `## Verification Gate` must be `passed`
8. Review only starts after the verification gate passes
9. **3-Strike errors**: diagnose → alternative → rethink → escalate to user

### Decision questions during implementation
- **low**: ask before unplanned files, alternatives, any deviation
- **med**: ask before plan deviations, cross-feature impact, 3-Strike
- **high**: ask only on convention conflicts, 3-Strike

## Completion
1. Fill `### Agent self-review` in plan.md:
   - Hardest: which decision was hardest to implement
   - Least confident: what might be wrong
   - Deviations: what differs from the plan and why
2. Verification gate complete (`## Verification Gate` is `passed`)
3. Acceptance gate complete (all properties pass, all checks done)
4. Review manually or escalate to user
5. Update `.spine/progress.md` → `done`
6. Present findings.md `## Promote to Project` candidates
7. Clear `.spine/active-feature` (write empty or remove file)

## Cleanup (mid-flow reset)
If user wants to start over or abandon current feature:
- Run `.spine/scripts/cleanup-features.sh reset <slug>` to remove
  feature dir and clear active
- Or `.spine/scripts/cleanup-features.sh clear-active` to just
  clear active marker
- User can then invoke `$spine-spec` or `$spine-pwf` for a new feature

## Session Recovery
1. `.spine/active-feature` → slug
2. Read only the active file's bottom `## Resume` block first
3. Load the primary file from `- Source:` (`spec.md` while speccing,
   `plan.md` once planning/execution starts)
4. During implementation, treat the approved `plan.md` as the only startup
   brief unless it is missing required detail
5. Do NOT load `.spine/project.md`, `.spine/conventions.md`,
   `.spine/progress.md`, `findings.md`, or `log.md` unless the plan is missing
   a needed fact, the code contradicts the plan, or a blocker needs deeper history
6. `git diff --stat` → changes when code may already exist
7. First product-code reads should come from the current implementation step's
  file tree entries
8. Check for unaddressed `> [R]:` only when the plan gate is pending
9. Resume — do NOT recreate plan/spec
