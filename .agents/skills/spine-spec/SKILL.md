---
name: spine-spec
description: >
  Define requirements for a feature before planning. Invoke explicitly
  with $spine-spec. Does NOT activate automatically.
allow_implicit_invocation: false
---

# Spine Spec: Requirements Definition

## Workflow

### Step 1: Context + codebase research
- Read `.spine/project.md`, `.spine/conventions.md`, `.spine/progress.md`
- Scan codebase for:
  - Existing code related to the feature area
  - Patterns already established (auth, API style, data access)
  - Potential conflicts or integration points
- Use explorer findings to inform questions (don't ask what the codebase already answers)

### Step 2: Detect role and adopt persona

**Product Owner** — when the feature is user-facing:
triggers: UI, user flow, notification, onboarding, dashboard, report, permission

Concerns to probe:
- Who are the users? What triggers this flow?
- What's the happy path? What does the user see/do at each step?
- What happens on failure? What feedback does the user get?
- Edge cases: empty states, first-time use, concurrent users
- Priority: MVP scope vs nice-to-have — what can we cut?
- Success metric: how do we know this feature works for users?

**Architect** — when the feature is technical/infrastructure:
triggers: migration, refactor, API, integration, performance, security, schema, deploy

Concerns to probe:
- What's the current state? What's broken or missing?
- Data flow: what goes in, transforms, comes out?
- Failure modes: what breaks? What's the blast radius?
- Migration: can we do it incrementally or is it all-or-nothing?
- Performance: latency budget? Throughput requirement?
- Security: auth, input validation, data exposure?
- Rollback: how do we undo this if it goes wrong?

**Both roles always ask:**
- What is explicitly NOT in scope?
- Dependencies on other features?
- Acceptance criteria — how do we verify it works?

### Step 3: Elicit requirements
Read autonomy from `.spine/config.yaml`:
- **low**: ask all relevant questions individually, confirm each
- **med**: ask 3-5 key questions (prioritized by role), infer rest, present for confirmation
- **high**: infer from codebase + context, present complete spec for approval

Adapt to what user already provided — skip answered questions.
Use explorer findings to make questions specific:
  BAD:  "What database will you use?"
  GOOD: "The codebase uses SQLite via internal/db. Should this feature use the same connection or need its own storage?"

### Step 4: Create spec file
- Slug (kebab-case) → `.spine/active-feature`
- Write `.spine/features/{slug}/spec.md`
- Tag the role used: `**Role:** product-owner` or `**Role:** architect`
- Every requirement must be testable
- Under 60 lines — if longer, split the feature
- No implementation details

### Step 5: STOP (Gate 1)
Update `.spine/progress.md` → status `specced`. Tell user:

> "Spec at `.spine/features/{slug}/spec.md`. Say **$spine-pwf {slug}** when ready to plan."

Do NOT auto-generate a plan.
