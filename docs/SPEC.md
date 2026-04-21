# Project Spine — Specification

## Problem

AI coding agents lose context across sessions, drift from architectural decisions,
and either impose too much ceremony (GSD) or too little project awareness
(Planning With Files). No existing framework gives the user a single dial to
control how much the agent asks before acting.

## Requirements

- REQ-1: Per-feature file isolation — each feature gets its own plan/findings/log
  in `.spine/features/{slug}/`, preventing cross-feature contamination.
- REQ-2: Project-level tracking — three small files (project.md, conventions.md,
  progress.md) maintain continuity across features while staying small enough for
  targeted on-demand reads.
- REQ-3: Single autonomy flag — `config.yaml` contains `autonomy: low|med|high`
  controlling approval cadence (action-level / plan-level / boundary-based).
- REQ-4: Session resilience — after `/clear` or new session, the agent recovers
  the active feature from a compact on-disk resume block, then loads deeper files
  only when the current phase requires them.
- REQ-5: Convention enforcement — agent reads `.spine/conventions.md` before
  implementation and flags conflicts rather than silently deviating.
- REQ-6: Spec creation skill — optional `$spine-spec` skill for fleshing out
  requirements before planning, producing `.spine/features/{slug}/spec.md`.
- REQ-7: Plan mode integration — framework uses Codex plan mode (Shift+Tab)
  for the design phase and structured PWF-style hooks for execution discipline.
- REQ-8: Hard verification gate — execution includes a context-minimized
  verifier step that receives only extracted proof artifacts from `plan.md`
  plus bounded test evidence, and blocks completion when coverage is weak.
- REQ-9: Explicit invocation — the framework does not activate automatically;
  users invoke `$spine-spec` or `$spine-pwf` when they want the workflow.
- REQ-10: Inspired by PWF — planning workflow uses PWF's proven patterns
  (3 files, hooks, 2-Action Rule, 3-Strike Protocol) reimplemented for
  `.spine/` directory structure without runtime dependency on PWF.
- REQ-11: Install/update scripts — `install.sh` and `update.sh` bootstrap or
  refresh the framework, copy files, patch AGENTS.md, and manage Codex config.

## Out of Scope

- Multi-agent orchestration
- XML plan formats, requirement IDs, traceability matrices
- Sprint ceremonies, story points, agile methodology
- Custom CLI commands or binaries
- Database or state machine — files are the state

## Acceptance Criteria

- [ ] Running `./install.sh` in a fresh repo creates all `.spine/` and `.codex/` files
- [ ] AGENTS.md is created (or appended to existing) with a short opt-in note
      that points workflow details to skills
- [ ] Codex CLI recognizes spine-spec and spine-pwf as available skills
- [ ] Creating a feature with `$spine-spec` produces spec.md in the correct location
- [ ] Spec template captures `Change type`, `Invariants`, and optional enforcement hints
- [ ] Planning workflow creates plan.md/findings.md/log.md in the correct feature directory
- [ ] Plan template includes a verifier packet contract and `## Verification Gate`
- [ ] `.spine/scripts/extract-verification-context.sh` emits only proof artifacts
- [ ] Stop hook blocks when `## Verification Gate` is not `passed` in verification/review phases
- [ ] Stop hook blocks when active-feature work remains incomplete
- [ ] SessionStart hook restores project and feature context
- [ ] `.spine/progress.md` updates on feature completion
- [ ] Existing `.codex/config.toml` files keep user settings
