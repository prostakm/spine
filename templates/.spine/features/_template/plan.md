# Feature: {FEATURE_NAME}

## Context
- Project: `.spine/project.md`
- Conventions: `.spine/conventions.md`
- Progress: `.spine/progress.md`
- Spec: `.spine/features/{slug}/spec.md` (if present)

**Goal:** {what this delivers — one sentence, specific}

**Approach:** {technical strategy + why — 1-2 sentences}

| Alternative | Why rejected |
|---|---|
| {alt} | {reason} |

**Risks:**
- {risk} → {mitigation}

---

<!--
PLAN DETAIL:
- File paths: exact, with create/modify/delete
- Types/schemas: fields, types, purpose
- Function signatures: params, returns, brief behavior
- Pseudocode: non-trivial logic + error paths (skip boilerplate)
- Context: point back to project.md, conventions.md, progress.md, spec.md
- Edge cases with handling
- Test cases by descriptive name
- Verify command per phase (if phased)

Split into phases only when the work has natural stages, dependencies
between parts, or is large enough to benefit from checkpoints.
Single-phase plans are fine for focused work.

See docs/EXAMPLE-PLAN.md for style reference.
-->

## Decisions
| Decision | Date | Rationale |
|----------|------|-----------|

## Errors
| Error | Attempt | Resolution |
|-------|---------|------------|

<!-- REVIEW: PENDING — add > [R]: comments inline, mark > [R]: APPROVED when done -->
