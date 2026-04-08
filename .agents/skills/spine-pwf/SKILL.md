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

## Plan Creation

### Planner ownership
- Draft or revise `.spine/features/{slug}/plan.md` for any non-trivial feature on the main thread
- Use targeted read-only research when it will materially improve the plan
- Keep the main thread responsible for approvals, tradeoff explanations, and the plan gate

### Detail requirements
The plan must include:
- **File paths**: exact, with create/modify/delete
- **Types/schemas**: field names, types, purpose
- **Function signatures**: params, returns, one-line behavior
- **Pseudocode**: for non-trivial logic and error paths (skip boilerplate)
- **Edge cases**: listed with handling approach
- **Test cases**: by descriptive name
- **Verify**: concrete command
- **Context**: a short section pointing to `.spine/project.md`, `.spine/conventions.md`, `.spine/progress.md`, and `.spine/features/{slug}/spec.md` when present

Split into phases only when work has natural stages or dependencies.
Single-phase plans are fine for focused tasks — don't add phases for ceremony.

See `docs/EXAMPLE-PLAN.md` for the expected style — terse, no prose filler.

### Style
- Bullet points over paragraphs
- Short statements, not sentences
- Code blocks for schemas/signatures/logic
- Alternatives and risks as compact tables/lists

### Decision involvement (from .spine/config.yaml)
- **low**: present 2-3 options, ASK user to pick. Ask about libs, patterns, scope.
- **med**: choose best, show alternatives table. ASK about architecture, new deps, API changes.
- **high**: decide with rationale. ASK only on conflicts.

## Plan Review (Gate 2)

After creating plan.md:

> "Plan at `.spine/features/{slug}/plan.md`. Review inline — add `> [R]:` comments next to anything you want changed. Mark `> [R]: APPROVED` when ready."

Then STOP.

### Inline review protocol
User adds `> [R]:` comments in plan.md, co-located with context:
```
func Login(w, r)
> [R]: add rate limiting — 5 attempts/IP/min
```

### On "address comments" / "apply review":
1. Find all `> [R]:` lines (not marked ✓)
2. Change requests → revise the plan
3. Questions → answer as `> [A]: response`
4. Mark done: `> [R]: ✓ original`
5. Changes made → STOP for re-review
6. `> [R]: APPROVED` → proceed

## Implementation (after Gate 2)

1. Work through phases sequentially
2. Keep user-facing workflow unchanged: implementation still happens inside this skill after plan approval
3. If the approved plan is incomplete or contradicted by the codebase, STOP and revise before coding
4. Keep trivial edits, integration decisions, and user communication on the main thread
5. SessionStart hook emits structured Spine context in current Codex session
6. **2-Action Rule**: after every 2 view/search/read ops → update findings.md
7. On phase completion: mark [x], status `complete`, update log.md, run Verify
8. After implementation, review manually or escalate to user
9. **3-Strike errors**: diagnose → alternative → rethink → escalate to user

### Decision questions during implementation
- **low**: ask before unplanned files, alternatives, any deviation
- **med**: ask before plan deviations, cross-feature impact, 3-Strike
- **high**: ask only on convention conflicts, 3-Strike

## Completion
1. All phases complete
2. Review manually or escalate to user
3. Update `.spine/progress.md` → `done`
4. Present findings.md `## Promote to Project` candidates
5. Clear `.spine/active-feature` (write empty or remove file)

## Cleanup (mid-flow reset)
If user wants to start over or abandon current feature:
- Run `.spine/scripts/cleanup-features.sh reset <slug>` to remove feature dir and clear active
- Or `.spine/scripts/cleanup-features.sh clear-active` to just clear active marker
- User can then invoke `$spine-spec` or `$spine-pwf` for a new feature

## Session Recovery
1. `.spine/active-feature` → slug
2. plan.md → current phase
3. findings.md + log.md → context
4. `git diff --stat` → changes
5. Check for unaddressed `> [R]:` → address first
6. Resume — do NOT recreate plan
