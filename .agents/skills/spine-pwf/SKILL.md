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
SPEC (opt) ──► STOP ──► PLAN ──► STOP ──► IMPLEMENT ──► REVIEW
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

### Workflow enforcement
- SessionStart, Stop, and OpenCode review gates are enforced by hooks/plugins
  outside this skill
- Do not work around those guards or treat them as optional
- If a hook or gate blocks progress, fix the workflow state instead of bypassing it
- While the plan gate is pending, only explicit edits to `plan.md` / `spec.md`
  and read-only commands are allowed

## Plan Review (Gate 2)

After creating plan.md:

> "Plan at `.spine/features/{slug}/plan.md`.
> Budget: ~{N} min. Start with 🔴 decisions, then properties.
> Review `Context` (skim spec-derived fields, deep-read Planning
> additions), `Decisions`, `Spec + proof`, and `Contracts`.
> Stop at the trust boundary.
> 🔴 GATE decisions need deep reading. 🟢 TRUST decisions are
> covered by properties — skip unless the properties look wrong.
> Criticality tags (⚠️ 🔒 🛡️ 👁️) mark volatile, locking, security,
> or UX-critical items — verify these first.
> Rules tagged [REQ-N] prove spec requirements — verify the fixture,
> don't re-approve the requirement.
> Mark properties you approve with `> [R]: ✓`.
> Add `> [R]:` comments next to anything you want changed.
> Mark `> [R]: APPROVED` when ready, or say `approved` / `plan approved` in chat.
> Mirror explicit chat approval into `plan.md` before implementation."

Then STOP.

### Inline review protocol
User adds `> [R]:` comments in plan.md, co-located with context:
```
**P1:** range: net pay is never negative
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
- Do not change the workflow shape:
  `spec/brainstorm (optional) -> plan -> approval -> implement -> review`

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

### Test-first sequence
For all strategies: implement property tests FIRST, then production code.
Properties in the plan are specifications. Implementation serves them.

- **CORRECTNESS**: write tests from properties and approved conditional fixtures first,
  then implement until tests pass
- **EQUIVALENCE**: capture equivalence anchor before changes, write
  preservation property test, then refactor, assert anchor holds
- **STRUCTURAL**: implement architecture constraint tests first
  (import checks, boundary assertions), then wire the plumbing
- **REGRESSION**: write reproduction test first (must fail on current
  code), then fix, then verify blast radius, then add the new
  invariant as a permanent property test

### Property authorship protection
Properties above the trust boundary are owned by the reviewer.

- **human** / **human-validated**: implement as written. Do not modify.
- **agent-proposed**: implement as written. Not trusted as proof until
  reviewer marks `> [R]: ✓`.
- Property appears wrong → STOP. Propose revision with `> [A]:`.
  Wait for reviewer approval. Do not silently adjust.
- Property is incomplete (missing edge case) → propose an additional
  property, mark it `agent-proposed`. Existing properties stay as-is.

### Property test implementation
- Use the project's property testing framework
  (Hypothesis, fast-check, jqwik, rapid, FsCheck, QuickCheck, etc.)
- If no property framework exists, add one as the first implementation
  step. Note the dependency in findings.md.
- Minimum 100 generated cases per property (exhaustive if domain is finite)
- Property test files live alongside but separate from example-based tests
- Preserve traceability: plan property → test function docstring/comment

### Execution rules
1. Work through the implementation strategy sequentially
2. If the approved plan is incomplete or contradicted by the codebase,
   STOP and revise before coding
3. Treat the approved `plan.md` as the startup brief and ongoing handoff;
   keep `## Resume`, acceptance checks, and the implementation packet current
4. **2-Action Rule**: after every 2 view/search/read ops → update findings.md
5. On each completed step: update acceptance checks, `## Resume`, and log.md
6. **3-Strike errors**: diagnose → alternative → rethink → escalate to user

### Decision questions during implementation
- **low**: ask before unplanned files, alternatives, any deviation
- **med**: ask before plan deviations, cross-feature impact, 3-Strike
- **high**: ask only on convention conflicts, 3-Strike

## Completion
1. Fill `### Agent self-review` in plan.md:
   - Hardest: which decision was hardest to implement
   - Least confident: what might be wrong
   - Deviations: what differs from the plan and why
2. Acceptance gate complete (all properties pass, all checks done)
3. Review manually or escalate to user
4. Update `.spine/progress.md` → `done`
5. Present findings.md `## Promote to Project` candidates
6. Clear `.spine/active-feature` (write empty or remove file)

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
