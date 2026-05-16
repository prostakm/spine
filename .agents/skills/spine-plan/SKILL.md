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

## Flow decomposition
- Identify 1-3 behavioral flows from the spec
- Common pattern: write paths and read paths separately
- A flow is one coherent path through the system
- If data moves in different directions through different components, split it
- Test: same trigger, same direction, same components? one flow
- Test: different trigger, direction, or component chain? two flows
- Cap at 3 flows; if a 4th appears, split the feature

## Plan structure

The template is canonical: `templates/.spine/features/_template/plan.md`.
The example is canonical style: `docs/EXAMPLE-PLAN.md`.

The plan has two zones separated by `<!-- TRUST BOUNDARY ... -->`.

**Above the boundary (reviewer reads top-down):**
- **Story**: 3-line narrative — change, gap, win
- **Status**: status, strategy, risk, scope
- **System view**: ASCII diagram of components and boundaries
- **Behaviors**: system-wide invariants, then 1-3 flow walkthroughs
  - each flow has ASCII diagram
  - each step uses `### A.1`, `### A.2`, `### B.1`, ...
  - each step has `> **Step intent:**`
  - decisions, properties, rules colocate at the step they govern
  - each step ends with `→ impl: [I3](#i3)` links
- **Acceptance matrix**: index view of rules/properties and tests
- EQUIVALENCE extras: `## Equivalence anchor` and `## Delta (perf)` may stand
  alone after flows; do not bury them in details

**Below the boundary (agent executes):**
- **Verification packet**: strategy, property IDs, rule IDs, verifier constraints
- **File manifest**: tree with `[M]`, `[C]`, `[D]`, and `→ I-refs`
- **Implementation**: every I-step is a unified diff
  - `#### I{N} — {short title} <a id="i{N}"></a>`
  - `Intent`: fallback if diff does not apply cleanly
  - `References`: D/P/R IDs implemented
  - `Critical`: optional `🔴` or `🟡`
  - fenced `diff`; new files diff from `/dev/null`
- **Acceptance gate**: commands and property/rule checks
- **Agent self-review**: fill after implementation
- **Verification Gate / Review Gate / State / Resume**: hook-readable blocks;
  DO NOT change their marker formats

## Voice
- Telegraph cavemen bullets
- Noun phrases or imperative fragments, not full sentences
- No connective tissue: drop "this means", "in order to", "because of that"
- File paths, identifiers, commands in backticks
- Decisions:
  - `- 🔴 **D1** — title`
  - `chose:` / `over:` / `why not:` / `consequence:`
- Properties:
  - `- 🔴 **P3** — invariant fact`
  - `holds:` / `test:` / `pattern:` / `never:`
- Rules:
  - rule fact in bold-ID line
  - `holds:` / `test:` / `never:` underneath
- Use `never:` by default; use `must not:` for security/regulatory negatives
- Imperative negatives, no subject: `never: archive a running run`

## Folding
- Use `<details>` for rationale; summary line is scan-speed fact
- Summary says the one reviewer-needed fact: `chose: timestamp column`
- Blank line required after `<summary>` and before `</details>` for nested markdown
- Always fold decision rationale beyond the summary
- Always fold property/rule deeper rationale beyond `holds:` + `test:` + `never:`
- Do not fold:
  - step-intent blockquotes
  - flow ASCII diagrams
  - system-wide invariant header + `holds:` + `test:`
  - equivalence anchor
  - delta perf table
  - acceptance matrix
  - anything below trust boundary

## Negative constraints
- Add `never:` at write sites, guard sites, idempotent operations, auth checks,
  and equivalence-preservation sites
- State a negative if a reasonable implementer might violate it unnoticed
- Cap at 1-3 sharp negatives per property/rule
- Skip negatives that are obviously wrong on code read
- Voice: imperative fragment, no subject

## Anchors and navigation
- Review-zone impl links use `[I{N}](#i{N})`
- Each I-step must include matching `<a id="i{N}"></a>`
- Stable anchors survive heading text edits
- Keep I-step order same as execution order

## Test specs
- Tests are named in the review zone via `test:` bullets and acceptance matrix
- Implementation diffs add/update the actual test files
- Every property or rule should map to at least one test, lint, script, or
  manual verification line

## Spec-to-plan derivation

The plan is the single source of truth for implementation. It MUST carry
forward all spec facts so the agent never needs to open spec.md.

Carry-forward (reviewer skims, does not re-approve):
- Spec Problem → plan Story / Status / Scope
- Spec I/O → flow diagrams or step intents
- Spec Change type → plan Strategy
- Spec Acceptance Criteria → Acceptance matrix + Acceptance gate
- Spec Flows → plan Behaviors

Enrichment (reviewer deep-reads - this is the plan's unique value):
- Actual touched files → File manifest
- Spec Requirements → Rules at flow steps
- Spec Invariants → Properties at flow/write/guard sites
- Spec Boundaries → Decisions with folded tradeoffs
- New review-relevant technical context → System view + step intent
- Verifier contract → Verification packet

**Key rule:** when a spec fact appears in the plan, mark its origin implicitly.
The reviewer should know whether reading spec context or new planning output.

**No spec present:** carry-forward fields are blank — the plan defines
everything from scratch. Reviewer treats all context as new.

- Approved `plan.md` must be sufficient to start implementation with only
  `## Resume`, `plan.md`, `git diff --stat`, and current I-step files
- Do not rely on implementation-time rereads of project docs when the relevant
  rule can be copied into the plan once
- If a file outside manifest must be reopened only to learn safe-edit facts,
  patch the plan instead of normalizing ad hoc exploration
- Prefer exact facts over summaries:
  - current function/component signatures inline with relevant step
  - existing helper names and test fixtures inline with relevant step
  - exact generated schema/type/export names when they affect edits
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
  ```text
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

### REGRESSION
- Reproduction (test, expected, actual)
- Blast radius (scope + verification suite)
- New invariant (the violated rule)
- Properties (the invariant encoded as a property)

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

## Property extraction

When writing the plan:
1. Pull invariants from spec.md `## Invariants` → candidate properties
2. Classify each by category: range | relational | stability |
   preservation | structural
3. Choose enforcement first: static | runtime | manual
4. Write properties with fields useful to reviewer:
   - `holds:` where invariant is enforced
   - `test:` evidence name
   - `pattern:` implementation pattern when helpful
   - `never:` negative constraint when useful
5. Properties go ABOVE the trust boundary — they are review artifacts
6. Test implementation details live below trust boundary in diffs
7. Write properties so they can be copied verbatim into a verifier packet
8. If spec has no invariants, elicit from codebase:
   - What return values are bounded? → range
   - What increases when input increases? → relational
   - What must stay the same after this change? → preservation
   - What architectural rules must hold? → structural

## Verification gate packet

Every plan must define a context-minimized verifier packet below the trust
boundary.

- Purpose: let a fresh verifier judge proof strength without reading full plan
- Extract only from approved proof artifacts above trust boundary:
  active strategy, properties, and strategy-specific invariants
- Executor adds bounded verification evidence separately: touched test/rule
  files, relevant test/rule names, commands run, pass/fail summary,
  generated-case counts where applicable, property-to-evidence mapping
- Verifier prompt asks which runtime mutants likely survive current evidence
  and which properties are weakly covered
- Do not apply mutation-style analysis to lint/formatter/static-rule proofs;
  ask whether rule meaningfully enforces invariant and what bypasses survive
- `## Verification Gate` starts pending and updates to passed/failed during execution

## Property authorship rule

- **human**: reviewer wrote it. Trusted proof.
- **human-validated**: agent proposed it, reviewer confirmed with `R> ✓`.
  Trusted proof.
- **agent-proposed**: agent wrote it, not yet validated. NOT trusted as proof
  until reviewer validates.

Agent MUST NOT modify human-authored property statements during implementation.
If implementation reveals a property is wrong → STOP, propose revision, wait
for `R>` approval.

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
- Caveman phrasing in lists. Sentence fragments over sentences.
- Decisions/properties/rules colocate at flow sites; standalone sections only
  for system-wide content.
- Bullet points over paragraphs everywhere else.
- Use `<details>` for rationale; summary line is scan-speed.
- Properties at write/guard sites get `never:` bullets.
- No markdown tables except Acceptance matrix and optional delta perf table.
- Bold only the smallest crucial fragment.
- Hard-wrap prose at 100 chars.
- Code blocks: language-tagged. `text` only for plain diagrams.
  Modifications use full unified `diff` snippets.
- Above trust boundary: optimize for review speed and signal.
- Below trust boundary: optimize for implementation accuracy.
- Below trust boundary: copy facts, not references, when needed for safe edits.
- File paths, symbols, commands in backticks.
- Metadata: key-value pairs, not prose paragraphs.

### Notation choices
- Data/control flow: `a → b → c` (inline, one line).
- Rules / fixtures: `- When {condition}, {observable}`.
- Provisions: properties + rules at flow steps.
- Domain invariants: property bullets with `holds:` + `test:` + `never:`.
- Endpoint behavior: grouped by endpoint, one line per case.
- Data shapes: colon-aligned code blocks.
- Alternatives: `chose:` / `over:` / `why not:` / `consequence:`.
- Side effects: `⚠` marker prefix.
- Criticality tags → callout mapping (use sparingly):
  - `⚠️` volatile  → `> [!CAUTION]`
  - `🔒` locks-in   → `> [!IMPORTANT]`
  - `🛡️` security   → `> [!WARNING]` (or `> [!CAUTION]` if severe)
  - `👁️` UX-critical → `> [!WARNING]`
  - no tag          → plain decision paragraph or `> [!TIP]` if useful
- Branching (2-3 paths): aligned cases or a fenced flow diagram.
- File manifest: tree-style with `[M]`/`[C]`/`[D]` markers.
- Implementation steps: code changes as full unified-diff snippets; new files
  as diffs from `/dev/null`.

### When to use diagrams
- System view: when touched files form >1 concern
- Flow diagram: one per behavioral flow
- Arch boundaries schematic: when reviewer needs to verify no arch violations
- Control flow tree: when branching logic has >2 paths and fixture arrows
  can't express decision structure
- If fixture arrows + ALWAYS/NEVER properties cover the concept, prefer those
- One diagram per concern, not per function

### Diagram notation
- Arch boundaries schematic: `───` locked, `───→` flow,
  `← NEW` / `← UNCHANGED` annotations.
- Control flow tree: `├──` / `└──` branching, `───→` outcomes.
- Use `...` to elide obvious/framework logic in code sketches.
- Use `#` annotations for decision-carrying lines in code sketches.
- Use `GUARD:` for boundary conditions.
- Use `⚠` for side effects within sketches.

### Tables
- Avoid tables in narrative plan content.
- Acceptance matrix is required and may use markdown table.
- EQUIVALENCE delta perf table may use markdown table.

## Plan Review (Gate 2)

Gate 2 is enforced mechanically: the PreToolUse hook blocks writes to
non-`.spine/` files while the plan is unapproved. Only edits to `plan.md` and
`spec.md` are allowed until approval is recorded.

Before requesting review:
- run `.spine/scripts/validate-plan.sh .spine/features/{slug}/plan.md`
- fix hard validation failures
- leave `## Review Gate` pending until explicit approval

Review prompt:

> Plan at `.spine/features/{slug}/plan.md`.
> Start with `Status` and top `Risk`.
> Then review `System view`, `Behaviors`, and `Acceptance matrix`.
> Stop at the trust boundary.
> Focus comments on chosen approach, proof cases, properties/rules, and missing risk.
> Mark properties you approve with `R> ✓`.
> Add `R>` comments next to anything you want changed.
> Mark `R> APPROVED` when ready, or say `approved` / `plan approved` in chat.
> Mirror explicit chat approval into `plan.md` before implementation.

Then STOP.

### Inline review protocol

User adds `R>` comments in `plan.md`, co-located with context:

```markdown
- **P1** — net pay is never negative
  - holds: payroll calculation
  - test: `test_net_pay_non_negative`
R> also add: net pay never exceeds gross pay
```

### On "address comments" / "apply review"

1. Find all `R>` lines not marked `✓`.
2. Change requests → revise the plan.
3. Questions → answer as `> [A]: response`.
4. Mark done: `R> ✓ original`.
5. If changes were made → STOP for re-review.
6. If `R> APPROVED` or explicit chat approval exists → mirror approval into
   `plan.md`, update matching I-step references, then hand off to `spine-implement`.

### Review invariants

- Reviewer reads above trust boundary only unless they want implementation detail.
- Reviewer comments go above the trust boundary.
- Approval phrase in chat must be mirrored into plan state before execution.
- If reviewer changes a property, decision, rule, or boundary, update matching
  I-step references before implementation starts.

## Strategy-driven implementation
- Executor follows I-steps in order
- If a diff does not apply, use `Intent` and `References` to adapt locally
- Do not change reviewed behavior while adapting diffs
- If adaptation changes a reviewed decision/property/rule, stop and ask
- Keep verification evidence tied back to property/rule IDs

See `docs/EXAMPLE-PLAN.md` for the expected style.
