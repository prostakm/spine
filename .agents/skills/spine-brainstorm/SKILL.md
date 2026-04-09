---
name: spine-brainstorm
description: >
  Explore intent and produce an approved feature spec before implementation
  planning. Use for ambiguous, behavior-changing, or multi-step work.
  Reads project context first, asks one clarifying question at a time,
  compares 2-3 approaches, and writes `.spine/features/{slug}/spec.md`.
  Progress is persisted incrementally for safe handoff at any point.
  Do NOT write code or implementation plans until the design is approved.
---

# Spine Brainstorm

## Purpose
Turn an idea into a short, approved design that is clear enough to hand off to
`spine-pwf`.

## When to Use
- Requests that change behavior, add a feature, or need design choices
- Tasks with unclear scope, constraints, or success criteria
- Multi-step work where the plan would otherwise guess at product intent
- Skip for: straightforward fixes, simple refactors, and direct implementation
  work where the user already gave a complete spec

## Workflow

### 0. Bootstrap (run once at start)
- Determine the feature slug in kebab-case from the user's request
- If slug is unclear, ask the user for one word/phrase
- Write the slug to `.spine/active-feature`
- Create `.spine/features/{slug}/` directory
- Create `.spine/features/{slug}/spec.md` with initial structure:

```markdown
# Feature: {slug}

## Status
- Brainstorm: in_progress
- Design: draft

## Discussion

## Approaches Considered

## Proposed Design

## Spec
```

### 1. Ground in project context
- Read `.spine/project.md`, `.spine/conventions.md`, and `.spine/progress.md`
- Inspect the relevant code paths before asking detailed questions
- If the request covers multiple independent subsystems, narrow it to one slice
  before continuing

### 2. Clarify intent
- Ask one clarifying question at a time
- Focus on user outcome, scope boundaries, constraints, and success criteria
- Prefer concrete options when the tradeoff is obvious
- After each Q&A exchange, append to `## Discussion` in spec.md:
  ```markdown
  ### Q: [question]
  A: [answer]
  ```

### 3. Compare approaches
- Present 2-3 viable approaches with tradeoffs
- Lead with the recommended option and explain why
- Keep it short; this is design guidance, not a plan
- After presenting approaches, write to `## Approaches Considered` in spec.md:
  ```markdown
  ### Approach A: [name]
  Tradeoffs: [description]
  
  ### Approach B: [name]
  Tradeoffs: [description]
  
  ### Recommended: [name]
  Reason: [why]
  ```

### 4. Present the design
- Present a concise design covering:
  - problem and user outcome
  - requirements and non-goals
  - key flow or architecture choices
  - verification / acceptance checks
- Write the proposed design to `## Proposed Design` in spec.md with `Status: draft`
- Get user approval before writing the spec
- After approval, update `## Proposed Design` status to `Status: approved`

### 5. Write the spec
- Consolidate the approved design into `## Spec` in spec.md
- Keep the spec focused and testable; if it grows too large, split the feature
- Include `## Change type` and `## Invariants` sections to help the
  planner select proof strategy
- **Splitting**: if the feature covers multiple independent concerns, propose splitting:
  1. Keep the primary concern in the current feature
  2. Create new feature dirs with spec.md containing YAML frontmatter `dependencies` referencing the current slug
  3. Move split-off features to backlog: `scripts/spine-backlog.sh move <slug>`
  4. The current feature's `dependents` list is auto-updated with backreferences
- Update `## Status` in spec.md:
  ```markdown
  ## Status
  - Brainstorm: complete
  - Design: approved
  - Spec: approved
  ```
- After writing, quickly self-check for placeholders, contradictions, and
  ambiguity

### 6. Hand off to planning
- Once the spec is approved, use `spine-pwf`
- Do NOT write code here

## Output Standard
- `spec.md` should be short and decision-complete for planning
- Record the chosen approach explicitly
- Leave no open design question that would force `plan.md` to invent behavior
- All Q&A, approaches, and design drafts are persisted incrementally

## Cleanup (mid-brainstorm reset)
If user wants to abandon or restart brainstorming:
- Run `.spine/scripts/cleanup-features.sh reset <slug>` to remove feature dir and clear active
- User can then start fresh with `$spine-brainstorm`
