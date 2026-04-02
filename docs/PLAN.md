# Project Spine — Implementation Plan

## Goal
Build a lightweight AI coding workflow framework for OpenAI Codex CLI that
combines Planning With Files' per-feature discipline with project-level
tracking, controlled by a single autonomy flag.

## Context
Spec: docs/SPEC.md
This is a framework (markdown files + bash scripts + TOML configs), not an app.
The deliverable is a repository that users clone/install into their projects.

## Phases

### Phase 1: Repository scaffolding
- [ ] Initialize git repo for project-spine
- [ ] Create directory structure:
      `.spine/`, `.spine/features/`, `.agents/skills/`, `.codex/agents/`
- [ ] Create `.gitignore` (ignore `.spine/active-feature`, keep templates)
- [ ] Create `README.md` with project overview and install instructions
- **Status:** pending

### Phase 2: Project-level files (templates)
- [ ] Create `templates/.spine/project.md` — example with placeholders
- [ ] Create `templates/.spine/conventions.md` — empty active section + decisions log
- [ ] Create `templates/.spine/progress.md` — empty dashboard with section headers
- [ ] Create `templates/.spine/config.yaml` — default autonomy:med, model mappings
- [ ] Create `templates/.spine/active-feature` — empty file
- [ ] Ensure all templates are under 40 lines each
- **Status:** pending

### Phase 3: Per-feature templates (patched PWF)
- [ ] Create `templates/.spine/features/_template/plan.md` — PWF's task_plan.md
      with added `## Context` header referencing project.md and conventions.md
- [ ] Create `templates/.spine/features/_template/findings.md` — PWF's findings.md
      with added `## Promote to Project` section at bottom
- [ ] Create `templates/.spine/features/_template/log.md` — PWF's progress.md
      (renamed to avoid confusion with project-level progress.md)
- [ ] Create `templates/.spine/features/_template/spec.md` — spec template
      for use by spine-spec skill
- **Status:** pending

### Phase 4: Hook scripts (patched PWF hooks for .spine/ paths)
- [ ] Create `hooks/pre-tool-use.sh`:
      reads active feature from `.spine/active-feature`,
      emits a structured reminder for `.spine/features/{slug}/plan.md`
- [ ] Create `hooks/post-tool-use.sh`:
      emits a structured reminder to update phase status in plan.md
- [ ] Create `hooks/stop.sh`:
      reads `.spine/active-feature`, checks if all phases in plan.md
      are marked complete, blocks stop if incomplete
- [ ] Create `hooks/session-start.sh`:
      reads `.spine/project.md` and `.spine/conventions.md`,
      reads active feature files for session recovery
- [ ] Test hooks with Codex CLI matcher-based hook configuration format
- **Status:** pending

### Phase 5: Codex skill definitions
- [ ] Create `.agents/skills/spine-pwf/SKILL.md`:
      planning-with-files skill adapted for .spine/ paths,
      references templates and hooks, describes explicit invocation,
      and documents worker/reviewer delegation rules
- [ ] Create `.agents/skills/spine-spec/SKILL.md`:
      spec creation skill with structured elicitation workflow,
      autonomy-aware questioning depth, 60-line spec cap,
      explicit invocation only
- **Status:** pending

### Phase 6: Subagent TOML definitions
- [ ] Create `.codex/agents/spine-explorer.toml`:
      name, description, model=gpt-5.4-mini, effort=medium,
      sandbox=read-only, instructions referencing .spine/ files
- [ ] Create `.codex/agents/spine-worker-simple.toml`:
      name, description, model=gpt-5.4-mini, effort=medium,
      instructions for routine plan-scoped implementation
- [ ] Create `.codex/agents/spine-worker-complex.toml`:
      name, description, model=gpt-5-codex, effort=medium,
      instructions for complex or escalation implementation work
- [ ] Create `.codex/agents/spine-worker.toml`:
      backward-compatible alias of the simple worker
- [ ] Create `.codex/agents/spine-reviewer.toml`:
      name, description, model=gpt-5.4, effort=high,
      sandbox=read-only, verification checklist instructions
- **Status:** pending

### Phase 7: AGENTS.md template
- [ ] Create `templates/AGENTS.md` with:
      - explicit invocation rules
      - workflow section with hard gates
      - model routing section (per-phase model × effort)
      - autonomy levels section (low/med/high behaviors)
      - delegation rules for simple/complex workers
      - execution rules for structured hooks
- [ ] Ensure it stays under 32KB (Codex project_doc_max_bytes default)
- [ ] Include markers for install script to merge with existing AGENTS.md
- **Status:** pending

### Phase 8: Config.toml template
- [ ] Create `templates/.codex/config.toml` with:
      - Main session model setting
      - Spine-managed developer instructions block
      - Hooks feature flag
      - Subagent limits (max_threads, max_depth)
- **Status:** pending

### Phase 9: Install and update scripts
- [ ] Create `install.sh` (bash, works on macOS + Linux):
      copies framework files without overwriting user project files,
      installs structured hooks at `.codex/hooks/`,
      writes matcher-based config to `.codex/hooks.json`,
      patches `.codex/config.toml` with the Spine-managed block,
      and stages framework files
- [ ] Create `update.sh`:
      refreshes framework files in place,
      adds worker-simple/complex definitions,
      migrates legacy `.codex/hooks/hooks.json` to `.codex/hooks.json`,
      and refreshes the managed config block
- [ ] Make both scripts idempotent
- **Status:** pending

### Phase 10: Documentation and README
- [ ] Write README.md: what, why, quickstart, file layout, autonomy levels
- [ ] Keep docs aligned with explicit invocation, worker split, and structured hooks
- [ ] Add LICENSE (MIT)
- **Status:** pending

## Decisions
- [pending]

## Errors
| Error | Attempt | Resolution |
|-------|---------|------------|
