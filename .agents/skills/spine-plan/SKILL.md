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

- **Context**: human context only. Summarize user goal, current baseline,
  scope choice, and dependency notes. Keep agent handoff out of this section.
- **Decisions**: only forks that need human judgment or lock in behavior.
  Start with flat bullets for `Goal`, `Approach`, and top `Risk`.
  Format decisions as Chose / Over / Locks / Covered by.
  Prefix each decision heading with a triage marker: 🔴 GATE
  (irreversible, deep-read), 🟡 REVIEW (reversible, non-trivial),
  🟢 TRUST (covered by proof). Max 7 decisions - split if more.
- **Spec + proof**: strategy-adaptive section. Include ONLY the block
  matching the chosen strategy, delete the rest. Prefer compact bullets,
  explicit conditionals, flow sketches, and fenced fixtures over prose.
- **Properties**: present in every strategy block. The primary proof
  artifact. See Property extraction below.
- **Contracts**: input/output types crossing boundaries. Skip for
  EQUIVALENCE and REGRESSION unless interfaces change.

**Below the trust boundary (agent executes, proofs verify):**

- **Applied constraints**: copy the specific rules from AGENTS,
  conventions, project docs, or external contracts that actually matter for
  this feature. Quote the source path and restate the rule locally so
  implementation does not need to reopen the source.
- **Codebase packet**: exact current signatures, focused snippets,
  test hooks/fixtures, generated names, and other current-state facts needed
  to edit safely. This is the anti-research packet for implementation.
- **File manifest**: exact paths with create/modify/delete, touched
  symbols, and what changes in each file
- **Implementation strategy**: steps referencing decisions by number.
  Phase if natural stages exist, flat if not. For every non-trivial
  step, include a code snippet or pseudocode sketch.
- **Test implementation notes**: exact test targets, framework,
  parametrize hints, generation strategies, snapshot names
- **Validation commands**: exact commands to run for the acceptance gate
- **Acceptance gate**: strategy-specific checklist, must include
  property verification and concrete validation commands when known
- The agent section must be executable from the plan alone. If an
  implementation detail would otherwise require reopening the codebase,
  spell it out here.
- **Resume**: keep it near the bottom so fresh sessions can recover with a
  quick tail read.

## Plan self-sufficiency

- The approved `plan.md` should be sufficient to start implementation with
  only `## Resume`, `plan.md`, `git diff --stat`, and then the current step's
  manifest files
- Do not rely on implementation-time rereads of `.spine/project.md`,
  `.spine/conventions.md`, `.spine/progress.md`, `findings.md`, `log.md`, or
  AGENTS files if the relevant rule can be copied into the plan once
- If a file outside the manifest must be reopened only to learn a fact needed
  for safe edits, the plan is missing context; patch the plan instead of
  normalizing ad hoc exploration
- Prefer exact facts over summaries:
  - current function/component signatures
  - existing helper names and test fixtures
  - short local snippets around touched logic
  - exact generated schema/type/export names
  - exact commands for verify/build/test

## Strategy-specific proof content

### CORRECTNESS
- Rules: fixture arrow notation for simple cases
  (`{input} → {expected}`); yaml blocks for complex
  conditionals with multiple interacting fields
- Properties (invariants over input domain)
- Snapshot anchors (outputs worth locking)
- Edge cases
- Logic sketch: optional, only when procedural logic has
  embedded decisions not captured by fixtures. Use `...`
  for obvious parts, `#` annotations on decision lines.

### EQUIVALENCE
- Equivalence anchor (what must not change, at what granularity)
- Existing suite requirement (all tests pass unmodified)
- Properties (preservation over input domain)
- Delta metric (perf only)

### STRUCTURAL
- Architecture constraints (import rules, permission checks)
- Boundary behavior: endpoint shorthand grouped by endpoint
  ```
  GET /path:
    condition → status + shape
    condition → status
  ```
- Flow sketch: optional. Use for selector chains, request derivation,
  or branching control flow when a bullet list is too lossy.
- Smoke tests (wiring proofs)
- Properties (structural invariants)

## Structural enforcement prompt

After drafting decisions, ask for each one:
"Can a type, linter rule, or shared utility make this
decision permanently unreviewable in future plans?"
If yes → note in the decision's Locks line and propose
a conventions.md entry. Each answer removes one item
from every future plan's review surface.

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
- First line of each section = its conclusion (BLUF)
- Hard-wrap prose at 100 chars. Rewrite to fit; do not overflow.
- Bold only the smallest crucial fragment. Never bold whole bullets.
- Delete unused strategy blocks from spec+proof — don't leave empty sections
- Every property needs a category label and an AUTHOR marker
- Above trust boundary: optimize for review speed and signal
- Below trust boundary: optimize for implementation accuracy
- Below trust boundary: copy facts, not references, when those facts are
  required for safe edits
- File paths, symbols, commands in backticks

### Notation choices
- Data/control flow: `a → b → c` (inline, one line)
- Test fixtures: `{input} → {expected}` (one line per case)
- Domain invariants: `- **P1:** {category}: {ALWAYS/NEVER statement}`
- Endpoint behavior: grouped by endpoint, one line per case
- Data shapes: colon-aligned `name: type  # constraint`
- Alternatives: Chose/Over/Locks (not prose paragraphs)
- Side effects: `⚠` marker prefix
- Branching (2-3 paths): aligned cases or a fenced flow sketch
- File manifest: `CREATE/MODIFY/DELETE path` prefix
- Metadata: key-value pairs, not tables

### When to use logic sketches
- ONLY for procedural logic with embedded decisions that
  can't be expressed as input→output fixtures
- Use `...` to elide obvious/framework logic
- Use `#` annotations for the decision-carrying lines
- Use `GUARD:` for boundary conditions
- Use `⚠` for side effects within sketches
- Use `NOT THIS: x / THIS: y` when wrong approach is obvious
- One sketch per component, not per function
- If fixture arrows + ALWAYS/NEVER cover the concept, prefer
  those — logic sketches are for the gap between them

### Tables
- Avoid tables in plans. Use fixture arrows, endpoint shorthand,
  key-value pairs, or indented trees instead.
- Tables only when >4 columns are genuinely needed AND
  all columns fit within 80 chars total.
- No table in the plan should exceed 80 characters wide.

See `docs/EXAMPLE-PLAN.md` for the expected style.
