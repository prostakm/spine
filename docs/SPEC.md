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
  progress.md) maintain continuity across features, totaling ≤700 tokens always-loaded.
- REQ-3: Single autonomy flag — `config.yaml` contains `autonomy: low|med|high`
  controlling approval cadence (action-level / plan-level / boundary-based).
- REQ-4: Session resilience — after `/clear` or new session, the agent recovers
  full context from on-disk files without user re-explanation.
- REQ-5: Convention enforcement — agent reads `.spine/conventions.md` before
  implementation and flags conflicts rather than silently deviating.
- REQ-6: Spec creation skill — optional `$spine-spec` skill for fleshing out
  requirements before planning, producing `.spine/features/{slug}/spec.md`.
- REQ-7: Subagent definitions — three custom Codex agents (explorer, worker,
  reviewer) with per-agent model and reasoning effort configuration.
- REQ-8: Plan mode integration — framework uses Codex plan mode (Shift+Tab)
  for the design phase and PWF hooks for the execution phase.
- REQ-9: Inspired by PWF — planning workflow uses PWF's proven patterns
  (3 files, hooks, 2-Action Rule, 3-Strike Protocol) reimplemented for
  `.spine/` directory structure without runtime dependency on PWF.
- REQ-10: Install script — single `install.sh` bootstraps the framework into
  any project: copies files, patches AGENTS.md, sets up config.

## Out of Scope

- Multi-agent orchestration beyond Codex's native subagent system
- XML plan formats, requirement IDs, traceability matrices
- Sprint ceremonies, story points, agile methodology
- Custom CLI commands or binaries
- Database or state machine — files are the state

## Acceptance Criteria

- [ ] Running `./install.sh` in a fresh repo creates all `.spine/` and `.codex/` files
- [ ] AGENTS.md is created (or appended to existing) with full workflow instructions
- [ ] Codex CLI recognizes spine-spec and spine-pwf as available skills
- [ ] Creating a feature with "create a spec for auth" produces spec.md in correct location
- [ ] Planning workflow creates plan.md/findings.md/log.md in correct feature directory
- [ ] PreToolUse hook reads plan from `.spine/features/{active}/plan.md`
- [ ] Stop hook checks phase completion in active feature's plan.md
- [ ] After `/clear`, agent can recover session from feature files
- [ ] `.spine/progress.md` updated on feature completion
- [ ] Subagent TOML files load correctly in Codex CLI
- [ ] Built-in `$plan` skill does not conflict (plan mode used for design, PWF for execution)
