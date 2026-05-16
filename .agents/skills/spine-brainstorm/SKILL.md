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

### 0a. Thumbnail (before creating files)
- State in 3 lines: what, why, blast radius
- Confirm direction with user before investing in full spec
- If user says "wrong direction" → no files were created, pivot cheaply
- Skip for features where user already gave detailed context

### 0b. Bootstrap (run once at start)
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

## Resume
- Source: spec
- Phase: spec
- Gate: pending
- Current Slice: clarify intent and converge on one design
- Next Step: ask the next highest-value question
- Open Questions: first unanswered design question
- Files in Play: `.spine/features/{slug}/spec.md`
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
- After each Q&A exchange, refresh `## Resume` so a fresh session can pick up
  with the latest current slice and next step.

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
- Before writing the design, run a quick pre-mortem:
  "Imagine this shipped and failed — what went wrong?"
  List 3 failure modes → these become constraints,
  edge cases, or invariants in the spec
- Present a concise design covering:
  - problem and user outcome
  - requirements and non-goals
  - key flow or architecture choices
  - invariants: what must always be true (use category vocabulary:
    range, relational, stability, preservation, structural)
  - enforcement hints: which invariants should be enforced statically vs at
    runtime
  - verification / acceptance checks
- Write the proposed design to `## Proposed Design` in spec.md with `Status: draft`
- Get user approval before writing the spec
- Explicit chat approval (`approved`, `spec approved`, `I approve`) counts here
  **but only for the spec gate — this does NOT authorize implementation.**
  After spec approval, you must STOP and transition to planning via `spine-pwf`.
  The PreToolUse hook mechanically blocks code writes until plan.md is approved.
- After approval, update `## Proposed Design` status to `Status: approved`
- Update `## Resume` to reflect whether the next action is re-review or spec write-up

### 5. Write the spec
- Consolidate the approved design into `## Spec` in spec.md
- Keep the spec focused and testable; if it grows too large, split the feature
- Include `## Change type` and `## Invariants` sections to help the
  planner select proof strategy. Use category labels:
  range, relational, stability, preservation, structural.
  When known, add `Enforcement hint: static | runtime | manual` under each
  invariant. Prefer `static` for architectural and source-shape rules that a
  type, linter, formatter, or repo script can enforce.
  If no invariants emerged during brainstorming, ask:
  "What must always be true about this feature, for any valid input?"
- Include `## Boundaries` with both `NOT:` exclusions and `DO NOT:`
  anti-patterns. Anti-patterns from the pre-mortem and discussion
  belong here.
- Include `## Flows` section: list 1-3 behavioral flows (data paths
  through the system) the change touches. Helps the planner decompose
  the plan along the same axes the reviewer uses to read it. Format:
  short bulleted list, one line per flow, naming the trigger and the
  components touched.
- Hard-wrap prose at 100 chars; rewrite to fit
- Bold only the smallest crucial fragment
- **Splitting**: if the feature covers multiple independent concerns, propose splitting:
  1. Keep the primary concern in the current feature
  2. Create new feature dirs with spec.md containing YAML frontmatter
     `dependencies` referencing the current slug
  3. Move split-off features to backlog: `scripts/spine-backlog.sh move <slug>`
  4. The current feature's `dependents` list is auto-updated with backreferences
- Update `## Status` in spec.md:
  ```markdown
  ## Status
  - Brainstorm: complete
  - Design: approved
  - Spec: approved
  ```
- Mirror any explicit chat approval into these status fields before handoff
- Update `## Resume` to point at planning handoff:
  `Phase: planning`, `Next Step: run $spine-pwf {slug}`
- Run `.spine/scripts/validate-spec.sh .spine/features/{slug}/spec.md`
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
