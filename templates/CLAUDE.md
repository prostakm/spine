# <!-- BEGIN PROJECT SPINE -->

## Project Context
Read `.spine/project.md` for vision, stack, and hard constraints.
Read `.spine/conventions.md` for coding conventions and architecture decisions.
Check `.spine/progress.md` for feature status and dependencies.
The active feature slug is in `.spine/active-feature`.

## Workflow

This project uses **Project Spine** — a file-based planning workflow.
All planning artifacts live in `.spine/features/{slug}/`.

### Starting a feature
1. Enter plan mode (`/plan`) for the design phase.
2. Read `.spine/project.md` and `.spine/conventions.md` before making design decisions.
3. If intent is ambiguous, use `/spine-brainstorm` first and write `spec.md`.
4. Write the feature slug to `.spine/active-feature`.
5. Create `.spine/features/{slug}/plan.md` from the template.
6. Draft `plan.md` so a fresh implementer can act from the plan alone.
7. Include `## Goal`, `## Scope Guardrails`, `## Codebase Anchors`,
   `## File Plan`, `## Current Slice`, `## Execution Slices`,
   `## Verification`, `## Review Gate`, and `## State`.
8. Run `.spine/scripts/validate-plan.sh .spine/features/{slug}/plan.md`.
9. Keep `## Review Gate` at `pending` and `## State` phase at `planning`.
10. Present the plan to the user for approval.
11. Record approval in `plan.md` before implementation begins.
12. Change `## State` phase to `implementation`.

### During execution
- `plan.md` is the source of truth for what to do next.
- Keep `## Current Slice`, `## Execution Slices`, and `## State` up to date as work progresses.
- Create `findings.md` or `log.md` only when the extra artifact adds real handoff value.

### Completing a feature
- Verify all slices marked complete in `plan.md`.
- Update `.spine/progress.md` with feature status.
- Promote durable decisions into `.spine/conventions.md`.

### Session recovery (after /clear or new session)
1. Read `.spine/active-feature` → current feature slug
2. Read `.spine/features/{slug}/plan.md`
3. Resume from `## Current Slice` and `## State`
4. Read `findings.md` or `log.md` only if `plan.md` explicitly points to them

## Execution Standard

### Codebase exploration
Use the main session with targeted file reads and concise summaries.
Return file paths and findings, not raw dumps.

### Planning
Planning is complete only when `plan.md` is fresh-context executable.
Every touched file needs an exact path, anchor, change shape, and verification.

### Implementation
Implement in the main session using the approved packet.
Read `plan.md`, follow `conventions.md`, stop on conflicts.

### Quick edits (single file, <20 lines)
Skip the planning workflow entirely.

### Code review
Run a dedicated review pass in the main session.
Check plan completion, convention compliance, and constraint respect.

### Deep architecture decisions
Log the decision in `conventions.md`.

## Autonomy (read from .spine/config.yaml)

### autonomy: low
- Ask more questions before the spec or plan is approved.
- Keep execution batching small after approval.

### autonomy: med
- Use one explicit review gate before implementation.
- Execute slices without frequent check-ins once approved.

### autonomy: high
- Bias toward inference during brainstorm and larger execution batches.
- Still record approval durably in `plan.md` before coding.

## Convention Enforcement
Before implementing, verify approach doesn't conflict with `.spine/conventions.md`.
Flag conflicts explicitly — never silently deviate.

# <!-- END PROJECT SPINE -->
