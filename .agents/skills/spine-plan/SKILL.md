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

Above the trust boundary (human reviews):

- **Changed code surface**: first review surface. List only touched product
  code and tests that matter for approval. Exclude `.spine/` bookkeeping files
  unless the feature itself changes Spine.
- **Context**: compact BLUF only. Focus on user goal, current gap, scope, and
  hard constraints the reviewer needs to judge the approach. Do not make the
  reviewer re-read broad project context or planner process notes.
- **Risk**: top-level, explicit, and brief. If risk drives review depth, say so.
- **Decisions**: only real forks. Constraints, conventions, or architecture
  rules are not decisions unless a competing option was considered. Default
  format: Chose / Over / Consequence. Keep it to what the reviewer is actually
  approving.
- **Spec + proof**: strategy-adaptive section. Use plain acceptance cases,
  compact structured examples, and strict properties. Prefer reviewer-readable
  proof artifacts over symbolic notation.
- **Properties**: present in every strategy block. Each property must say what
  must hold, how it will be enforced, why that enforcement is appropriate, and
  what evidence proves it.
- **Contracts**: input/output types crossing boundaries. Use language-tagged
  fences that match the content (`typescript` when the content is TS-like).
  Include only the contracts that clarify review.

Below the trust boundary (agent executes, proofs verify):

- **Codebase packet**: exact current signatures, focused snippets,
  test hooks/fixtures, generated names, and other current-state facts needed
  to edit safely. This is the anti-research packet for implementation.
- **Verification evidence**: bounded verifier packet plus the concrete runtime
  or static evidence the executor must collect.
- **File tree**: secondary execution overview. Neotree-style tree of touched
  files with `[M]`/`[C]`/`[D]` markers. Collapse non-scoped siblings with
  `(...)`. One-line change descriptions per file.
- **Implementation strategy**: steps referencing decisions by number.
  Phase if natural stages exist, flat if not. For every non-trivial step,
  include a near-real code sketch in the repo language; use pseudocode only
  when no concrete syntax is possible.
- **Acceptance gate**: references Properties by number. Validation command
  is the first checkbox. Use lint/type/script checks when a property is enforced
  statically; use runtime tests only for runtime behavior.
- The agent section must be executable from the plan alone. If an
  implementation detail would otherwise require reopening the codebase,
  spell it out here.
- **Resume**: keep it near the bottom so fresh sessions can recover with a
  quick tail read.

## Spec-to-plan derivation

The plan is the single source of truth for implementation. It MUST carry
forward all spec facts so the agent never needs to open spec.md.

Carry-forward (reviewer skims, does not re-approve):
- Spec Problem → plan Context (user goal, current gap, scope)
- Spec I/O → plan Contracts (if types are complete; otherwise enriched)
- Spec Change type → plan Strategy header
- Spec Acceptance Criteria → plan Acceptance gate (delegated, not restated)

Enrichment (reviewer deep-reads - this is the plan's unique value):
- Actual touched files → plan Changed code surface
- Spec Requirements → plan Rules as plain acceptance cases
- Spec Invariants → plan Properties with proof framing + enforcement markers
- Spec Boundaries → plan Decisions with Chose/Over/Consequence tradeoffs
- New review-relevant technical context → fold into compact plan Context
- Verifier contract → plan Verification evidence + Verification Gate skeleton

**Key rule:** when a spec fact appears in the plan, mark its origin
implicitly (Strategy derived from spec, Goal distilled from spec). The reviewer
should always know whether they're reading spec context or new planning output.

**No spec present:** carry-forward fields are blank — the plan defines
everything from scratch. Reviewer treats all context as new.

- The approved `plan.md` should be sufficient to start implementation with
  only `## Resume`, `plan.md`, `git diff --stat`, and then the current step's
  file tree entries
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
- Rules: plain acceptance cases for simple scenarios; compact yaml blocks for
  complex conditionals with multiple interacting fields
- Properties (invariants over input domain)
- Snapshot anchors (outputs worth locking)
- Edge cases
- Arch boundaries schematic: optional, when the change touches
  multiple layers. Shows locked vs changed boundaries with
  decision and property references inline.
- Control flow tree: optional, when branching has >2 paths.
  Shows decision outcomes, not variable names.
- Code sketch: optional, only when procedural logic has
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
- Flow diagram: optional. Use for selector chains, request derivation,
  or branching control flow when a bullet list is too lossy.
  See Diagram notation below for tree-style format.
- Arch boundaries schematic and control flow tree: same as CORRECTNESS
  block — apply when structural changes touch multiple layers or have
  branching paths.
- Smoke tests (wiring proofs)
- Properties (structural invariants)

## Enforcement ladder

For every decision and property, prefer the strongest cheapest enforcement that
matches the invariant:

1. Type system
2. Linter / formatter / static analysis rule
3. Repo validation script
4. Runtime test
5. Manual review

Use runtime tests for runtime behavior. Do not use tests to compensate for a
missing static rule when the invariant is purely structural or source-shaped.

Good static-enforcement candidates:
- import boundaries
- forbidden APIs or helpers
- page/controller/query ownership rules
- naming or file-placement conventions
- raw literal / token usage bans
- formatting and generated-file invariants

Good runtime-enforcement candidates:
- business rules
- numeric invariants
- data-dependent rendering
- async branching behavior
- API semantics

If the same structural proof appears more than once, treat it as a promotion
candidate immediately:
- ask `promote to lint/helper/script now?`
- prefer shared lint/rule/script enforcement in the product repo over bespoke
  per-feature structural tests
- record promotion candidates in `findings.md`

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
3. Choose the enforcement mode first: static | runtime | manual
4. Write properties in plain English with input domain descriptions
   and strict labels:
   - `Invariant`
   - `Enforcement`
   - `Why`
   - `Evidence`
5. Properties go ABOVE the trust boundary — they are review artifacts
6. Test details (below trust boundary, inline in Implementation strategy)
   specify the framework and generation strategies only for runtime-enforced
   properties
7. Write properties so they can be copied verbatim into a verifier packet.
   Avoid references that require reading the implementation section to recover
   meaning.
8. If spec has no invariants, elicit from the codebase:
   - What return values are bounded? → range
   - What increases when input increases? → relational
   - What must stay the same after this change? → preservation
   - What architectural rules must hold? → structural

## Verification gate packet

Every plan must define a context-minimized verifier packet below the trust
boundary.

- Purpose: let a fresh verifier judge proof strength without reading the full
  plan or the implementation strategy
- Extract only from the approved proof artifacts above the trust boundary:
  active strategy, properties, and strategy-specific invariants
- The executor adds bounded verification evidence separately: touched test or
  rule files, relevant test names or rule names, commands run, pass/fail
  summary, generated-case counts where applicable, and property-to-evidence
  mapping
- The verifier prompt should ask which runtime mutants would likely survive the
  current runtime evidence and which properties are only weakly covered.
  Do not apply mutation-style analysis to lint/formatter/static-rule proofs;
  for those, ask whether the rule meaningfully enforces the invariant and what
  bypasses would still survive.
- `## Verification Gate` starts as `pending` and is updated to `passed` or
  `failed` during execution

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
- Start with changed code surface, then compact context. Reviewers should not
  need to dig for the real change surface.
- Delete unused strategy blocks from spec+proof — don't leave empty sections
- Every property needs an AUTHOR marker and the labels Invariant / Enforcement /
  Why / Evidence
- Above trust boundary: optimize for review speed and signal
- Below trust boundary: optimize for implementation accuracy
- Below trust boundary: copy facts, not references, when those facts are
  required for safe edits
- Below trust boundary: define verification packet fields explicitly so the
  verifier never needs the full plan
- File paths, symbols, commands in backticks

### Notation choices
- Data/control flow: `a → b → c` (inline, one line)
- Acceptance cases: `- When {condition}, {observable}`
- Domain invariants: strict labeled property bullets
- Endpoint behavior: grouped by endpoint, one line per case
- Data shapes: colon-aligned `name: type  # constraint`
- Alternatives: Chose/Over/Consequence (not prose paragraphs)
- Side effects: `⚠` marker prefix
- Criticality tags: `⚠️` volatile, `🔒` locks future, `🛡️` security,
  `👁️` UX-critical. Append to decision headings, properties, rules,
  or edge cases. Use sparingly — most items get no tag.
- Branching (2-3 paths): aligned cases or a fenced flow diagram
- File tree: neotree-style `▾`/`●` with `[M]`/`[C]`/`[D]` markers in the
  agent zone; keep the first overview as changed code surface
- Metadata: key-value pairs, not tables

### When to use diagrams
- Arch boundaries schematic: when the change touches multiple layers
  and the reviewer needs to verify no arch violations. Shows locked
  vs changed boundaries. Reference decisions and properties inline.
- Control flow tree: when branching logic has >2 paths and fixture
  arrows can't express the decision structure. Shows outcomes,
  not variable names or code.
- If fixture arrows + ALWAYS/NEVER properties cover the concept,
  prefer those — diagrams are for the gap between them.
- Both diagrams are human-zone artifacts. The agent zone's
  Implementation strategy shows the correct code-level flow.
- One diagram per concern, not per function.

### Diagram notation
- Arch boundaries schematic: `───` locked, `───→` flow,
  `← NEW` / `← UNCHANGED` annotations
- Control flow tree: `├──` / `└──` branching, `───→` outcomes
- Use `...` to elide obvious/framework logic in code sketches
- Use `#` annotations for decision-carrying lines in code sketches
- Use `GUARD:` for boundary conditions
- Use `⚠` for side effects within sketches

### Tables
- Avoid tables in plans. Use acceptance bullets, endpoint shorthand,
  key-value pairs, or indented trees instead.
- Tables only when >4 columns are genuinely needed AND
  all columns fit within 80 chars total.
- No table in the plan should exceed 80 characters wide.

See `docs/EXAMPLE-PLAN.md` for the expected style.
