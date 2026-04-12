---
name: spine-plan
description: >
  Create strategy-adaptive plans with property-based proof sketches.
  Used by spine-pwf during the planning phase.
allow_implicit_invocation: false
---

# Spine Plan

## Planner ownership
- Draft or revise `.spine/features/{slug}/plan.md` for any non-trivial
  feature on the main thread
- Use targeted read-only research when it will materially improve the plan
- Keep the main thread responsible for approvals, tradeoff explanations,
  and the plan gate

## Strategy selection

Pick based on the nature of the change (from spec.md `## Change type` if present):

| Change type | Strategy |
|---|---|
| New business logic, domain rules | CORRECTNESS |
| Refactor, performance, migration | EQUIVALENCE |
| New endpoint, wiring, infrastructure | STRUCTURAL |
| Bug fix | REGRESSION |

Only CORRECTNESS requires new domain knowledge from the reviewer.
All others verify preservation of existing behavior.

## Plan structure

The plan has two zones separated by a trust boundary:

**Above the trust boundary (human reviews):**

- **Decisions**: only forks that need human judgment or lock in behavior.
  Start with one-line `Goal` and `Approach`. Format decisions as
  Chosen / Over / Consequence. Max 7 — split if more.
- **Spec + proof**: strategy-adaptive section. Include ONLY the block
  matching the chosen strategy, delete the rest. Prefer compact bullets,
  explicit conditionals, and fenced fixtures over scaffolding.
- **Properties**: present in every strategy block. The primary proof
  artifact. See Property extraction below.
- **Contracts**: input/output types crossing boundaries. Skip for
  EQUIVALENCE and REGRESSION unless interfaces change.

**Below the trust boundary (agent executes, proofs verify):**

- **File manifest**: exact paths with create/modify/delete, touched
  symbols, and what changes in each file
- **Implementation strategy**: steps referencing decisions by number.
  Phase if natural stages exist, flat if not. For every non-trivial
  step, include a code snippet or pseudocode sketch.
- **Test implementation notes**: exact test targets, framework,
  parametrize hints, generation strategies, snapshot names
- **Acceptance gate**: strategy-specific checklist, must include
  property verification and concrete validation commands when known
- The agent section must be executable from the plan alone. If an
  implementation detail would otherwise require reopening the codebase,
  spell it out here.

## Strategy-specific proof content

### CORRECTNESS
- Rules as explicit condition -> expectation cases. Use one-line
  conditional fixtures for simple cases; use compact structured blocks
  for complex conditionals.
- Properties (invariants over input domain)
- Snapshot anchors (outputs worth locking)
- Edge cases

### EQUIVALENCE
- Equivalence anchor (what must not change, at what granularity)
- Existing suite requirement (all tests pass unmodified)
- Properties (preservation over input domain)
- Delta metric (perf only)

### STRUCTURAL
- Architecture constraints (import rules, permission checks)
- Boundary cases as explicit request/context -> expected outcomes. Use
  compact structured blocks if auth, flags, or state make the condition
  non-trivial.
- Smoke tests (wiring proofs)
- Properties (structural invariants)

### REGRESSION
- Reproduction (test, expected, actual)
- Blast radius (scope + verification suite)
- New invariant (the violated rule)
- Properties (the invariant encoded as a property)

## Property extraction

When writing the plan:
1. Pull invariants from spec.md `## Invariants` → candidate properties
2. Classify each by category: range | relational | stability |
   preservation | structural
3. Write properties in plain English with input domain descriptions
4. Properties go ABOVE the trust boundary — they are review artifacts
5. Test implementation notes (below trust boundary) specify the
   framework and generation strategies
6. If spec has no invariants, elicit from the codebase:
   - What return values are bounded? → range
   - What increases when input increases? → relational
   - What must stay the same after this change? → preservation
   - What architectural rules must hold? → structural

## Property authorship rule

- **human**: reviewer wrote it. Trusted proof.
- **human-validated**: agent proposed it, reviewer confirmed with
  `> [R]: ✓`. Trusted proof.
- **agent-proposed**: agent wrote it, not yet validated. NOT trusted
  as proof until reviewer validates.

Agent MUST NOT modify human-authored property statements during
implementation. If implementation reveals a property is wrong → STOP,
propose revision, wait for `> [R]:` approval.

Properties the agent can't express clearly → escalate to reviewer.

## Splitting features

If the plan reveals the feature is too large or covers multiple concerns:
1. Keep the current feature focused on what's actionable now
2. Create new feature dirs with spec.md containing YAML frontmatter
   `dependencies` referencing the current slug
3. Move split-off features to backlog:
   `scripts/spine-backlog.sh move <slug>`
4. Resume planning the current (now smaller) feature

## Decision involvement (from .spine/config.yaml)

- **low**: present 2-3 options, ASK user to pick. Ask about libs,
  patterns, scope.
- **med**: choose best, show brief rejected options. ASK about
  architecture, new deps, API changes.
- **high**: decide with rationale. ASK only on conflicts.

## Style
- Bullet points over paragraphs
- Short statements, not sentences
- Code blocks for schemas/signatures/logic
- No tables in active plans. Encode conditionals directly in bullets or
  compact structured blocks.
- Delete unused strategy blocks from spec+proof — don't leave empty sections
- Every property needs a category label and an AUTHOR marker
- Above trust boundary: optimize for review speed and signal
- Below trust boundary: optimize for implementation accuracy
- File paths, symbols, commands in backticks

See `docs/EXAMPLE-PLAN.md` for the expected style.
