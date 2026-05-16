---
name: spine-closeout
description: >
  Complete a Project Spine feature after verification passes. Used by
  spine-pwf. Does NOT activate automatically.
allow_implicit_invocation: false
---

# Spine Closeout

## Entry condition

- `## Verification Gate` is `passed`.
- Acceptance gate is complete or all remaining items are explicitly out of scope.

## Completion

1. Fill `### Agent self-review` in `plan.md`:
   - Hardest: which decision was hardest to implement
   - Least confident: what might be wrong
   - Deviations: what differs from the plan and why
2. Confirm verification gate complete: `## Verification Gate` is `passed`.
3. Confirm acceptance gate complete: all properties pass, all checks done.
4. Run final review manually or escalate to user, according to autonomy level.
5. Update `.spine/progress.md` → feature `done`.
6. Present `findings.md` `## Promote to Project` candidates.
7. Clear `.spine/active-feature` by writing empty content or removing the file.

## Review handoff

- Review starts only after verification gate passes.
- If review finds behavior drift or weak evidence, return to `spine-implement` or
  `spine-verify` as appropriate.
- Do not mark done while acceptance checklist items remain unchecked.
