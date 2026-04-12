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

## Planning phase
Use **spine-plan** skill for plan creation.
Planning is complete when `plan.md` passes `.spine/scripts/validate-plan.sh`.

### Workflow enforcement
- SessionStart, Stop, and OpenCode review gates are enforced by hooks/plugins
  outside this skill
- Do not work around those guards or treat them as optional
- If a hook or gate blocks progress, fix the workflow state instead of bypassing it

## Plan Review (Gate 2)

After creating plan.md:

> "Plan at `.spine/features/{slug}/plan.md`.
> Review above the trust boundary — decisions, properties, contracts.
> Properties are the proof: check they encode the right domain rules.
> Mark properties you approve with `> [R]: ✓`.
> Add `> [R]:` comments next to anything you want changed.
> Mark `> [R]: APPROVED` when ready."

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
6. `> [R]: APPROVED` → proceed

## Implementation (after Gate 2)

### Delegation discipline
- Main thread owns approvals, integration decisions, and final user communication
- Keep trivial edits on the main thread
- If blocked or stuck, escalate to the user rather than spawning additional agents
- Do not change the workflow shape: spec/brainstorm (optional) -> plan -> approval -> implement -> review

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
3. **2-Action Rule**: after every 2 view/search/read ops → update findings.md
4. On each completed step: update acceptance checks, update log.md
5. **3-Strike errors**: diagnose → alternative → rethink → escalate to user

### Decision questions during implementation
- **low**: ask before unplanned files, alternatives, any deviation
- **med**: ask before plan deviations, cross-feature impact, 3-Strike
- **high**: ask only on convention conflicts, 3-Strike

## Completion
1. Acceptance gate complete (all properties pass, all checks done)
2. Review manually or escalate to user
3. Update `.spine/progress.md` → `done`
4. Present findings.md `## Promote to Project` candidates
5. Clear `.spine/active-feature` (write empty or remove file)

## Cleanup (mid-flow reset)
If user wants to start over or abandon current feature:
- Run `.spine/scripts/cleanup-features.sh reset <slug>` to remove
  feature dir and clear active
- Or `.spine/scripts/cleanup-features.sh clear-active` to just
  clear active marker
- User can then invoke `$spine-spec` or `$spine-pwf` for a new feature

## Session Recovery
1. `.spine/active-feature` → slug
2. plan.md → current state and implementation status
3. findings.md + log.md → context
4. `git diff --stat` → changes
5. Check for unaddressed `> [R]:` → address first
6. Resume — do NOT recreate plan
