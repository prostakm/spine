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
The plan has two zones separated by a trust boundary:

**Above the trust boundary (human reviews):**
- **Strategy selector**: CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION
  Pick based on the nature of the change. Only CORRECTNESS requires
  new domain knowledge from the reviewer.
- **Decisions**: every fork where the agent needs human judgment.
  Format: Chosen / Over / Consequence. Max 7 — split if more.
- **Spec + proof**: strategy-adaptive section. Include ONLY the block
  matching the chosen strategy, delete the rest:
  - CORRECTNESS: rules with fixture tables, Hypothesis properties,
    snapshot anchors, edge cases
  - EQUIVALENCE: equivalence anchor (what must not change), existing
    suite requirement, delta metric (perf only)
  - STRUCTURAL: architecture constraints (import rules, permission checks),
    boundary behavior table, smoke tests
  - REGRESSION: reproduction test (expected vs actual), blast radius,
    new invariant if warranted
- **Contracts**: input/output types crossing boundaries. Skip for
  EQUIVALENCE and REGRESSION unless interfaces change.

**Below the trust boundary (agent executes, proofs verify):**
- **File manifest**: exact paths with create/modify/delete
- **Implementation strategy**: steps referencing decisions by number.
  Phase if natural stages exist, flat if not.
- **Test implementation notes**: parametrize hints, Hypothesis
  strategies, snapshot format
- **Acceptance gate**: strategy-specific checklist

**Splitting features**: if the plan reveals the feature is too large or covers
multiple concerns, propose splitting into smaller features:
1. Keep the current feature focused on what's actionable now
2. Create new feature dirs with spec.md containing YAML frontmatter `dependencies` referencing the current slug
3. Move split-off features to backlog: `scripts/spine-backlog.sh move <slug>`
4. The current feature's `dependents` list is auto-updated with backreferences
5. Resume planning the current (now smaller) feature

See `docs/EXAMPLE-PLAN.md` for the expected style — terse, no prose filler.

### Style
- Bullet points over paragraphs
- Short statements, not sentences
- Code blocks for schemas/signatures/logic
- Alternatives and risks as compact tables/lists
- Delete unused strategy blocks from spec+proof — don't leave empty sections

### Decision involvement (from .spine/config.yaml)
- **low**: present 2-3 options, ASK user to pick. Ask about libs, patterns, scope.
- **med**: choose best, show alternatives table. ASK about architecture, new deps, API changes.
- **high**: decide with rationale. ASK only on conflicts.

## Plan Review (Gate 2)

After creating plan.md:

> "Plan at `.spine/features/{slug}/plan.md`.
> Review sections 1-4 (above the trust boundary).
> Add `> [R]:` comments next to anything you want changed.
> Mark `> [R]: APPROVED` when ready."

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

### Strategy-driven implementation
- CORRECTNESS: write tests from section 3 fixtures/properties FIRST,
  then implement until tests pass
- EQUIVALENCE: capture equivalence anchor BEFORE any changes,
  then refactor, then assert anchor matches
- STRUCTURAL: implement architecture constraints as linter rules
  or structural tests FIRST, then wire the plumbing
- REGRESSION: write the reproduction test FIRST (must fail on
  current code), then fix, then verify blast radius

1. Work through the implementation strategy sequentially
2. Keep user-facing workflow unchanged: implementation still happens inside this skill after plan approval
3. If the approved plan is incomplete or contradicted by the codebase, STOP and revise before coding
4. Keep trivial edits, integration decisions, and user communication on the main thread
5. SessionStart hook emits structured Spine context in current Codex session
6. **2-Action Rule**: after every 2 view/search/read ops → update findings.md
7. On each completed implementation step: update acceptance checks, update log.md, and run the strategy-appropriate verification
8. After implementation, review manually or escalate to user
9. **3-Strike errors**: diagnose → alternative → rethink → escalate to user

### Decision questions during implementation
- **low**: ask before unplanned files, alternatives, any deviation
- **med**: ask before plan deviations, cross-feature impact, 3-Strike
- **high**: ask only on convention conflicts, 3-Strike

## Completion
1. Acceptance gate complete
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
2. plan.md → current state and implementation status
3. findings.md + log.md → context
4. `git diff --stat` → changes
5. Check for unaddressed `> [R]:` → address first
6. Resume — do NOT recreate plan
