---
name: spine-pwf
description: >
  File-based planning workflow for complex features. Activate for any task
  touching more than one file or needing more than 5 tool calls.
  Creates plan.md, findings.md, and log.md in .spine/features/{slug}/.
  Do NOT use for single-file quick edits or simple questions.
  Do NOT confuse with the built-in $plan skill — this skill manages
  persistent planning files on disk, not in-memory plans.
---

# Spine PWF: File-Based Planning Workflow

## When to Use
- Any task that modifies multiple files
- Any task expected to take more than 5 tool calls
- When the user says "plan", "implement feature", "build", or describes a multi-step task
- Skip for: single-file edits <20 lines, simple questions, quick fixes

## Workflow

### Before Starting
1. Read `.spine/project.md` for constraints
2. Read `.spine/conventions.md` for active conventions
3. Check `.spine/progress.md` for related features
4. Determine feature slug from user's description (kebab-case, e.g., `auth-system`)
5. Write slug to `.spine/active-feature`
6. Create `.spine/features/{slug}/` directory
7. Copy templates from `.spine/features/_template/` if files don't exist

### Planning (in Plan mode)
1. If spec.md exists, read it for requirements
2. Create plan.md with 3-7 phases, each with concrete checkboxes
3. Fill in the `## Context` section with relevant constraints and conventions
4. Present plan to user for approval
5. Do NOT write code until plan is approved

### Execution (after switching to Execute mode)
1. Work through phases sequentially
2. The PreToolUse hook automatically refreshes plan.md in context
3. After every 2 view/search/read operations, update findings.md (2-Action Rule)
4. When completing a phase:
   - Mark checkboxes as [x] in plan.md
   - Change status to `complete`
   - Update log.md with actions and files modified
5. On errors: log in plan.md Errors table
   - Strike 1: Diagnose root cause
   - Strike 2: Try alternative approach
   - Strike 3: Rethink strategy or escalate to user

### Completion
1. Verify all phases marked complete
2. Update `.spine/progress.md` with feature status
3. Review findings.md `## Promote to Project` for convention candidates
4. Inform user of any promotion candidates

### Session Recovery (after /clear)
1. Read `.spine/active-feature` for current slug
2. Read plan.md, findings.md, log.md for full context
3. Run `git diff --stat` for code changes
4. Resume from current in_progress phase
