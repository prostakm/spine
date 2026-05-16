---
name: spine-pwf
description: >
  Thin orchestrator for Project Spine's file-based planning workflow.
  Invoke explicitly with $spine-pwf or "use spine" / "spine plan".
  Does NOT activate automatically.
allow_implicit_invocation: false
---

# Spine PWF

## Role

Workflow orchestrator only. Route phases, maintain gates, and keep lifecycle
state coherent. Delegate phase detail to subskills:

| Phase | Owner |
|---|---|
| spec / design | `spine-spec` or `spine-brainstorm` |
| plan + plan review | `spine-plan` |
| implementation | `spine-implement` |
| verification | `spine-verify` |
| closeout | `spine-closeout` |

Do not duplicate phase-specific rules here. Load the owning subskill when that
phase starts.

## Gates — stop at each, never auto-advance

```text
SPEC (opt) ──► STOP ──► PLAN ──► STOP ──► IMPLEMENT ──► VERIFY ──► REVIEW
               "plan {slug}"    user reviews plan.md
                                inline R> comments
                                marks APPROVED
```

- 🔴 **NEVER skip a gate.** A PreToolUse hook mechanically blocks writes to
  non-.spine files while plan.md is unapproved. Do not work around it.
- Spec approval ≠ plan approval. Saying "approved" after reading a spec means
  Gate 1 passes — you MUST now invoke spine-plan, not start coding.
- Explicit chat approval counts only after it is mirrored into `plan.md` or
  `spec.md` state.
- If a hook or gate blocks progress, fix workflow state instead of bypassing it.

## Setup

1. Read `.spine/project.md`, `.spine/conventions.md`, `.spine/progress.md`.
2. Determine slug in kebab-case from user input or `.spine/active-feature`.
3. Write slug to `.spine/active-feature`.
4. Create `.spine/features/{slug}/` from `.spine/features/_template/` if missing.
5. Keep `## Resume` current in the active `spec.md` or `plan.md`.
   - short
   - phase-accurate
   - near bottom for tail-based recovery

## Dispatch table

| Current state | Action |
|---|---|
| No slug | ask for slug, then Setup |
| No spec needed and no plan | load `spine-plan`; create `plan.md` |
| `spec.md` active / spec gate pending | stop; user approves spec or invokes planning |
| `plan.md` missing / draft | load `spine-plan`; draft or revise plan |
| Plan review pending | load `spine-plan`; address `R>` comments only |
| Plan approved | load `spine-implement`; execute approved I-steps |
| Implementation evidence ready | load `spine-verify`; run verification gate |
| Verification gate failed | load `spine-implement`; strengthen evidence, then verify again |
| Verification gate passed | load `spine-closeout`; self-review, review, progress update |
| User abandons / restarts | Cleanup |

## Planning handoff

Use `spine-plan` for:
- plan creation and revision
- validation with `.spine/scripts/validate-plan.sh`
- Gate 2 review prompt
- inline `R>` protocol
- approval mirroring

While the plan gate is pending:
- only explicit edits to `plan.md` / `spec.md` and read-only commands are allowed
- allowed read-only commands include plan validators such as
  `.spine/scripts/validate-plan.sh`, `scripts/validate-plan.sh`, and `./...`
  variants

## Implementation handoff

Use `spine-implement` after Gate 2 approval. The approved `plan.md` is the
implementation source of truth.

## Verification handoff

Use `spine-verify` after planned static rules, scripts, and tests pass.
`## Verification Gate` must be `passed` before review or completion.

## Closeout handoff

Use `spine-closeout` after verification passes. It owns self-review, progress
update, promote-to-project candidates, and clearing `.spine/active-feature`.

## Cleanup — mid-flow reset

If user wants to start over or abandon current feature:
- run `.spine/scripts/cleanup-features.sh reset <slug>` to remove feature dir
  and clear active
- or run `.spine/scripts/cleanup-features.sh clear-active` to just clear active
  marker
- user can then invoke `$spine-spec`, `$spine-brainstorm`, or `$spine-pwf` for a
  new feature

## Session recovery

1. Read `.spine/active-feature` → slug.
2. Read only the active file's bottom `## Resume` block first.
3. Load the primary file from `- Source:`:
   - `spec.md` while speccing
   - `plan.md` once planning/execution starts
4. During implementation, treat the approved `plan.md` as the only startup brief
   unless it is missing required detail.
5. Do not load `.spine/project.md`, `.spine/conventions.md`,
   `.spine/progress.md`, `findings.md`, or `log.md` unless:
   - the plan lacks a needed fact
   - code contradicts the plan
   - a blocker needs deeper history
6. Run `git diff --stat` when code may already exist.
7. First product-code reads come from current I-step file manifest entries.
8. Check unaddressed `R>` only when the plan gate is pending.
9. Resume existing state. Do not recreate plan/spec.
