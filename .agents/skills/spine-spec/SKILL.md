---
name: spine-spec
description: >
  Define requirements for a feature before planning. Use when the user wants
  to flesh out what a feature should do before implementation. Triggers on:
  "spec", "specify", "requirements", "what should this do", "define the feature".
  Do NOT use for implementation planning (that's spine-pwf) or quick edits.
---

# Spine Spec: Requirements Definition

## Purpose
Turn a vague feature idea into a concrete, testable specification
that feeds into the planning workflow.

## Workflow

### Step 1: Read project context
- Read `.spine/project.md` for constraints and stack
- Read `.spine/conventions.md` for conventions
- Read `.spine/progress.md` for related/dependent features

### Step 2: Elicit requirements
Read autonomy from `.spine/config.yaml`:
- **low**: Ask all questions individually, confirm each answer
- **med**: Ask 2-3 key questions, infer the rest, present for confirmation
- **high**: Infer as much as possible, present complete spec for single approval

Questions to cover (adapt to what user already provided):
1. **What** — What does this feature do? What problem does it solve?
2. **Who** — Who uses it? What triggers it?
3. **Boundaries** — What is explicitly NOT in scope?
4. **Inputs/Outputs** — What data goes in? What comes out?
5. **Constraints** — Performance? Security? Reference .spine/project.md.
6. **Dependencies** — Related features in .spine/progress.md?
7. **Verification** — How do we know it works? Acceptance criteria?

### Step 3: Create spec file
- Determine feature slug (kebab-case)
- Write slug to `.spine/active-feature`
- Create `.spine/features/{slug}/spec.md` using the spec template
- Every requirement MUST be testable
- Keep spec under 60 lines — if longer, split the feature
- No implementation details (no "use library X")

### Step 4: Hand off
After user approves:
1. Update `.spine/progress.md`: add feature with status `specced`
2. Tell user: "Spec complete. Start planning with: plan the {slug} feature"
