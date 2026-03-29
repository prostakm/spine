# <!-- BEGIN PROJECT SPINE -->

## Project Context
Read `.spine/project.md` for vision, stack, and hard constraints.
Read `.spine/conventions.md` for coding conventions and architecture decisions.
Check `.spine/progress.md` for feature status and dependencies.
The active feature slug is in `.spine/active-feature`.

## Workflow

This project uses **Project Spine** — a file-based planning workflow.
Do NOT use `~/.codex/plans/` for plan storage. All planning artifacts
live in `.spine/features/{slug}/`.

### Starting a feature
1. Enter Plan mode (Shift+Tab or /plan) for the design phase.
2. Write the feature slug to `.spine/active-feature`.
3. Create `.spine/features/{slug}/` with plan.md, findings.md, log.md from templates.
4. Read `.spine/project.md` for constraints and `.spine/conventions.md` for conventions.
5. If a spec is needed, use the `$spine-spec` skill first.
6. Draft the plan in plan.md (3-7 phases with checkboxes).
7. Present plan to user for approval.
8. On approval, switch to Execute mode (Shift+Tab) and begin implementation.

### During execution
- The PreToolUse hook refreshes plan.md before every write/edit/bash operation.
- After every 2 view/search/read operations, update findings.md (2-Action Rule).
- When a phase completes: update plan.md status, update log.md with actions taken.
- On errors: log in plan.md Errors table, follow 3-Strike Protocol
  (diagnose → alternative approach → rethink strategy → escalate).

### Completing a feature
- Verify all phases marked complete in plan.md.
- Update `.spine/progress.md` with feature status.
- Review findings.md `## Promote to Project` section — promote to conventions.md if approved.

### Session recovery (after /clear or new session)
1. Read `.spine/active-feature` → current feature slug
2. Read `.spine/features/{slug}/plan.md` → current phase and goal
3. Read `.spine/features/{slug}/findings.md` → research context
4. Read `.spine/features/{slug}/log.md` → what was done
5. Run `git diff --stat` → what code changed
6. Resume from the current in_progress phase.

## Model Routing

### Specification ($spine-spec)
Use gpt-5.4 at reasoning effort high. Interactive requirements elicitation.

### Codebase exploration
Spawn `spine_explorer` subagent (gpt-5.4-mini, medium effort, read-only).
Return concise summaries with file paths, not raw content.

### Planning
Use gpt-5.4 at reasoning effort high in the main session.

### Implementation
Spawn `spine_worker` subagent (gpt-5.3-codex, high effort).
Worker reads plan.md, follows conventions.md, stops on conflicts.

### Quick edits (single file, <20 lines)
Use gpt-5.3-codex-spark. Skip planning workflow entirely.

### Code review
Spawn `spine_reviewer` subagent (gpt-5.4, high effort, read-only).
Checks plan completion, convention compliance, constraint respect.

### Deep architecture decisions
Use gpt-5.4 at reasoning effort xhigh. Log decision in conventions.md.

## Autonomy (read from .spine/config.yaml)

### autonomy: low
- Never spawn subagents without explicit user request.
- Present plan for approval before each phase.
- Pause after each phase for user confirmation.
- Never auto-promote conventions.

### autonomy: med
- Spawn spine_explorer during plan creation.
- Present plan for user approval (single gate).
- Execute phases without pausing after approval.
- Spawn spine_reviewer after final phase.
- Escalate on: convention conflicts, constraint violations, 3-strike errors.

### autonomy: high
- Auto-spawn exploration. Auto-approve plans if no conflicts.
- Parallelize independent phases with spine_worker subagents.
- Auto-promote conventions matching existing patterns.
- Escalate only on: conflicts, 3-strike threshold, scope creep.

## Convention Enforcement
Before implementing, verify approach doesn't conflict with `.spine/conventions.md`.
Flag conflicts explicitly — never silently deviate.

# <!-- END PROJECT SPINE -->
