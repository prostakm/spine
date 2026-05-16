---
name: spine-implement
description: >
  Execute an approved Project Spine plan. Used by spine-pwf after the plan
  review gate passes. Does NOT activate automatically.
allow_implicit_invocation: false
---

# Spine Implement

## Entry condition

- `plan.md` exists and is approved.
- Explicit chat approval has been mirrored into `plan.md`.
- No unresolved `R>` change requests remain.

## Delegation discipline

- Main thread owns approvals, integration decisions, and final user communication.
- Keep trivial edits on the main thread.
- If blocked or stuck, escalate to the user rather than spawning additional agents.
- Exception: one fresh context-minimized verifier subagent is required after the
  planned evidence passes and before review/completion.
- Do not change the workflow shape:
  `spec/brainstorm (optional) -> plan -> approval -> implement -> verify -> review`.

## Plan-first execution

- Approved `plan.md` is the implementation source of truth.
- Start implementation from the approved plan, not broad project re-reading.
- If the plan already carries needed constraints and current-state facts, do not
  reopen `.spine/project.md`, `.spine/conventions.md`, `.spine/progress.md`,
  `findings.md`, or `log.md`.
- First product-code reads after the plan come from the current I-step file tree
  entries.
- If implementation needs a fact not in the plan — signature, snippet, test hook,
  generated name, repo instruction — stop and patch the plan first rather than
  rebuilding context ad hoc.

## Proof-first sequence

For all strategies: implement the plan's strongest enforcement first, then
production code. Properties in the plan are specifications. Implementation
serves them.

- **Static-enforced properties**: add the type, lint, formatter, or repo script
  rule first when the invariant is structural or source-shaped.
- **CORRECTNESS**: write runtime tests from properties and approved fixtures
  first, then implement until tests pass.
- **EQUIVALENCE**: capture equivalence anchor before changes, add the lightest
  preservation proof that matches the invariant, then refactor, assert anchor
  holds.
- **STRUCTURAL**: implement lint/type/script enforcement first where possible;
  add smoke tests only for runtime wiring or boundary behavior.
- **REGRESSION**: write the reproduction check first; if the bug is structural,
  prefer a static rule over a permanent runtime regression test.

## Property authorship protection

Properties above the trust boundary are owned by the reviewer.

- **human** / **human-validated**: implement as written. Do not modify.
- **agent-proposed**: implement as written. Not trusted as proof until reviewer
  marks `R> ✓`.
- Property appears wrong → stop. Propose revision with `> [A]:`. Wait for
  reviewer approval. Do not silently adjust.
- Property is incomplete → propose an additional property, mark it
  `agent-proposed`. Existing properties stay as-is.

## Property implementation

- For `Enforcement: static`, implement the rule in the strongest practical
  layer: type system, linter/static analysis, formatter, or repo validation
  script.
- For `Enforcement: runtime`, use the project's property testing framework
  (Hypothesis, fast-check, jqwik, rapid, FsCheck, QuickCheck, etc.).
- If no property framework exists and runtime properties require one, add it as
  the first implementation step. Note the dependency in `findings.md`.
- Minimum 100 generated cases per runtime property; exhaustive if the domain is
  finite.
- Property test files live alongside but separate from example-based tests.
- Preserve traceability: plan property → evidence source (rule, script, or test).

## Execution rules

1. Work through implementation I-steps sequentially.
2. If the approved plan is incomplete or contradicted by the codebase, stop and
   revise before coding.
3. Treat approved `plan.md` as the startup brief and ongoing handoff; keep
   `## Resume`, acceptance checks, and the implementation packet current.
4. **2-Action Rule**: after every 2 view/search/read ops → update `findings.md`.
5. Workflow friction is first-class: if a hook, validator, or review ritual slows
   or blocks progress, record it in `findings.md` `## Workflow Friction` with
   trigger, impact, and suggested fix before moving on.
6. On each completed step: update acceptance checks, `## Resume`, and `log.md`;
   every log entry includes `Workflow friction`, even when value is `none`.
7. Before review or completion: `## Verification Gate` must be `passed`.
8. Review only starts after verification gate passes.
9. **3-Strike errors**: diagnose → alternative → rethink → escalate to user.

## Decision questions during implementation

- **low**: ask before unplanned files, alternatives, any deviation.
- **med**: ask before plan deviations, cross-feature impact, 3-Strike.
- **high**: ask only on convention conflicts, 3-Strike.
