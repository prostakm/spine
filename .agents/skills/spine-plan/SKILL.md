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

The plan has two zones separated by a trust boundary.

**Above the boundary (reviewer reads top-down):**

- **Overview**: system-flow diagram (caveman boxes, one short sentence per
  box, no provision IDs) + file map (tree-style with `[M]/[C]/[D]` markers).
- **Context**: 6 lines max — Goal / Gap / In / Out / Constraints / Spec link.
- **Chapters**: each chapter is a coherent review unit. Per chapter:
  - **Why grouped** (1–3 prose sentences) — argues why this is one unit.
  - **What changes** (1–2 sentences) — system-level summary.
  - **Decisions**: real forks only. Format: Chose / Over / Consequence.
    Use callouts (`> [!CAUTION/WARNING/IMPORTANT]`) sparingly.
  - **Provisions**: chapter-scoped formal claims, in this order:
    *Properties*, *Rules / fixtures*, *Boundary behavior*, *Edge cases*.
    Skip subsections that don't apply.
- **Contracts**: only when boundaries change. Inputs/outputs as code blocks.

**Below the boundary (agent executes):**

- **Implementation tracks**: each track is independently verifiable.
  Per track:
  - **Depends on**: prior tracks or none.
  - **Constraints**: imperative directives in caveman form (extracted from
    decisions).
  - **Code**: modifications as full `diff` snippets with file/line location
    in the `####` heading and hunk header. Include enough unchanged context
    for safe placement. New files use plain language-tagged blocks. Each code
    block lives under a `####` heading.
  - **Tests**: each test under a `####` heading; body is `In:` / `Assert:`
    bullets in caveman form. No code stubs, no parametrize blocks spelled
    out.
  - **Verify**: bash commands.
  - **Green when**: criteria referencing test names from above.
- **Verification evidence**: verifier packet + mutation candidates +
  static-proof gaps.
- **Verification Gate / Review Gate / State / Resume**: hook-readable
  blocks. DO NOT change their format.
- **Acceptance gate**: checklist of track green-criteria + cross-cutting
  checks.

## Anchors and navigation

Every code block and test spec gets a `####` heading. Cross-links use
`[label](#slug)` where slug is computed from the heading by:

1. lowercase
2. drop punctuation (dot, comma, colon, quotes, brackets, `*`, `~`, backtick, etc.; keep `_`)
3. drop slashes
4. replace runs of whitespace with single `-`

Examples:
- `#### Modify payroll/calculator.py lines 42-88` →
  `#modify-payrollcalculatorpy-lines-42-88`
- `#### \`test_total_withholding_never_negative\`` →
  `#test_total_withholding_never_negative`

Slugs match GitHub and marksman (nvim) — same anchor works in PR review and
in editor `gd` navigation.

## Test specs

Each test spec is a `####` heading + bullet body:

```markdown
#### `test_name`

*Unit | Hypothesis property | Snapshot | Parametrized | Component | Hook*.
Proves PX (and PY if multiple).

- In: {input/setup, code-shaped where helpful}
- Assert: {expectation, code-shaped where helpful}
- Note: {optional, e.g. example count, snapshot path, slow marker}
```

Multiple assertions sub-bullet under Assert. Code-shape is preferred when
clearer than prose: `result ≥ Money(0, "USD")` over "result is non-negative
Money".

## Spec-to-plan derivation

The plan is the single source of truth for implementation. It MUST carry
forward all spec facts so the agent never needs to open spec.md.

Carry-forward (reviewer skims, does not re-approve):
- Spec Problem → plan Context (user goal, current gap, scope)
- Spec I/O → plan Contracts (if types are complete; otherwise enriched)
- Spec Change type → plan Strategy header
- Spec Acceptance Criteria → plan Acceptance gate (delegated, not restated)

Enrichment (reviewer deep-reads - this is the plan's unique value):
- Actual touched files → plan Overview file map
- Spec Requirements → plan Rules as plain acceptance cases
- Spec Invariants → plan Properties with proof framing + enforcement tags
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
  - current function/component signatures inline with the step that edits them
  - existing helper names and test fixtures inline with the step that uses them
  - short local snippets around touched logic inline with the relevant step
  - exact generated schema/type/export names when they affect the step
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
4. Write properties with exactly two fields:
   - `Invariant`: category + what must hold (plain English)
   - `Evidence`: the test, rule, script, or check that proves it
   Use callouts only for the most review-critical properties:
   `> [!{CALLOUT}] **P{N}** — {enforcement} — {author}`
   Lower-priority properties can be plain bullets:
   `- **P{N}** — {enforcement} — {author}`
5. Properties go ABOVE the trust boundary — they are review artifacts
6. Test details (below trust boundary, inline in Implementation tracks)
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
  plan or the implementation tracks
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
- Caveman phrasing in lists. Sentence fragments over sentences.
- Prose only for `Why grouped` and `What changes` — they argue, lists state.
- Bullet points over paragraphs everywhere else.
- No markdown tables. Use fenced `text` blocks if tabular data is needed.
- Bold only the smallest crucial fragment.
- Hard-wrap prose at 100 chars.
- Code blocks: language-tagged. `text` only for plain diagrams (trees,
  flowcharts). Modifications use full `diff` snippets with file/line location.
- Above trust boundary: optimize for review speed and signal.
- Below trust boundary: optimize for implementation accuracy.
- Below trust boundary: copy facts, not references, when those facts are
  required for safe edits.
- File paths, symbols, commands in backticks.
- Metadata: key-value pairs, not tables.

### Notation choices
- Data/control flow: `a → b → c` (inline, one line).
- Rules / fixtures: `- When {condition}, {observable}`.
- Provisions: Properties + Rules / fixtures + Boundary behavior + Edge cases.
- Domain invariants: property bullets with `Invariant` + `Evidence` fields.
- Endpoint behavior: grouped by endpoint, one line per case.
- Data shapes: colon-aligned code blocks.
- Alternatives: Chose/Over/Consequence (not prose paragraphs).
- Side effects: `⚠` marker prefix.
- Criticality tags → callout mapping (use sparingly):
  - `⚠️` volatile  → `> [!CAUTION]`
  - `🔒` locks-in   → `> [!IMPORTANT]`
  - `🛡️` security   → `> [!WARNING]` (or `> [!CAUTION]` if severe)
  - `👁️` UX-critical → `> [!WARNING]`
  - no tag          → plain decision paragraph or `> [!TIP]` if useful
- Branching (2-3 paths): aligned cases or a fenced flow diagram.
- File map: tree-style with `[M]`/`[C]`/`[D]` markers in Overview.
- Implementation tracks: code changes as full unified-diff snippets with
  file/line location; new files as full language-tagged blocks.

### When to use diagrams
- System flow: when touched files form >1 concern. One box per concern.
- Arch boundaries schematic: when reviewer needs to verify no arch violations.
- Control flow tree: when branching logic has >2 paths and fixture arrows
  can't express the decision structure. Shows outcomes, not variable names.
- If fixture arrows + ALWAYS/NEVER properties cover the concept, prefer those.
- One diagram per concern, not per function.

### Diagram notation
- Arch boundaries schematic: `───` locked, `───→` flow,
  `← NEW` / `← UNCHANGED` annotations.
- Control flow tree: `├──` / `└──` branching, `───→` outcomes.
- Use `...` to elide obvious/framework logic in code sketches.
- Use `#` annotations for decision-carrying lines in code sketches.
- Use `GUARD:` for boundary conditions.
- Use `⚠` for side effects within sketches.

### Tables
- Avoid tables in plans.
- If reviewer wants tabular data, use fenced `text` blocks.
- Do not use markdown tables in chapter content.

See `docs/EXAMPLE-PLAN.md` for the expected style.
