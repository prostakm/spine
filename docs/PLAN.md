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
      cats first 30 lines of `.spine/features/{slug}/plan.md`
- [ ] Create `hooks/post-tool-use.sh`:
      echoes reminder to update phase status in plan.md
- [ ] Create `hooks/stop.sh`:
      reads `.spine/active-feature`, checks if all phases in plan.md
      are marked complete, blocks stop if incomplete
- [ ] Create `hooks/session-start.sh`:
      reads `.spine/project.md` and `.spine/conventions.md`,
      reads active feature files for session recovery
- [ ] Create PowerShell equivalents: `hooks/*.ps1` for Windows
- [ ] Test hooks with Codex CLI hook configuration format
- **Status:** pending

### Phase 5: Codex skill definitions
- [ ] Create `.agents/skills/spine-pwf/SKILL.md`:
      planning-with-files skill adapted for .spine/ paths,
      references templates and hooks, describes trigger conditions
      ("complex task", "multi-step", "new feature"),
      explicitly states "Do NOT use built-in $plan skill for file creation"
- [ ] Create `.agents/skills/spine-spec/SKILL.md`:
      spec creation skill with structured elicitation workflow,
      autonomy-aware questioning depth, 60-line spec cap,
      triggers on "spec", "specify", "requirements", "define feature"
- [ ] Create `agents/openai.yaml` for both skills (UI metadata, invocation policy)
- **Status:** pending

### Phase 6: Subagent TOML definitions
- [ ] Create `.codex/agents/spine-explorer.toml`:
      name, description, model=gpt-5.4-mini, effort=medium,
      sandbox=read-only, instructions referencing .spine/ files
- [ ] Create `.codex/agents/spine-worker.toml`:
      name, description, model=gpt-5.3-codex, effort=high,
      instructions for plan-scoped implementation
- [ ] Create `.codex/agents/spine-reviewer.toml`:
      name, description, model=gpt-5.4, effort=high,
      sandbox=read-only, verification checklist instructions
- **Status:** pending

### Phase 7: AGENTS.md template
- [ ] Create `templates/AGENTS.md` with:
      - Project context section (read .spine/ files)
      - Workflow section (plan mode for design, PWF for execution)
      - Model routing section (per-phase model × effort)
      - Autonomy levels section (low/med/high behaviors)
      - Convention enforcement section
      - Commit conventions section
- [ ] Ensure it stays under 32KB (Codex project_doc_max_bytes default)
- [ ] Include markers for install script to merge with existing AGENTS.md
- **Status:** pending

### Phase 8: Config.toml template
- [ ] Create `templates/.codex/config.toml` with:
      - Main session model setting
      - Subagent limits (max_threads, max_depth)
      - Comment explaining built-in $plan relationship
- **Status:** pending

### Phase 9: Install script
- [ ] Create `install.sh` (bash, works on macOS + Linux):
      1. Detect if inside a git repo (fail gracefully if not)
      2. Add PWF submodule: `git submodule add ... vendor/planning-with-files`
      3. Copy templates/.spine/ → .spine/ (skip if exists, don't overwrite)
      4. Copy templates/.codex/ → .codex/ (merge if config.toml exists)
      5. Copy .agents/skills/ → .agents/skills/ (Codex skill discovery path)
      6. Copy .codex/agents/ → .codex/agents/ (subagent definitions)
      7. Handle AGENTS.md: if exists, append spine section with separator;
         if not, copy template
      8. Run `git add .spine/ .codex/ .agents/ AGENTS.md`
      9. Print summary of what was created
      10. Print "Run `codex` to get started. Use $spine-spec to define a feature."
- [ ] Create `install.ps1` for Windows (PowerShell equivalent)
- [ ] Make install.sh idempotent (safe to run twice)
- **Status:** pending

### Phase 10: Documentation and README
- [ ] Write README.md: what, why, quickstart, file layout, autonomy levels
- [ ] Write docs/WORKFLOW.md: full lifecycle walkthrough with examples
- [ ] Write docs/MODELS.md: model routing rationale and customization guide
- [ ] Write docs/CUSTOMIZATION.md: how to change models, add conventions, adjust autonomy
- [ ] Add LICENSE (MIT)
- **Status:** pending

## Decisions
- [pending]

## Errors
| Error | Attempt | Resolution |
|-------|---------|------------|
