# Project Spine

A lightweight AI coding workflow framework for [OpenAI Codex CLI](https://developers.openai.com/codex/cli).

Combines [Planning With Files](https://github.com/OthmanAdi/planning-with-files)' per-feature discipline with project-level tracking, controlled by a single autonomy flag.

## Why

| Problem | GSD's answer | PWF's answer | Spine's answer |
|---|---|---|---|
| Context lost between sessions | 15 agents, 40+ workflows | 3 files per task | 3 files per feature + session hooks |
| No project-level awareness | PROJECT.md + ROADMAP.md + STATE.md (grows unbounded) | None | 3 small files (~700 tokens total) |
| Too much / too little ceremony | All or nothing | Always lightweight | `autonomy: low\|med\|high` config flag |
| Architecture drift across features | Conventions in STATE.md (buried) | No cross-feature memory | conventions.md checked before every implementation |

## Install

```bash
# Clone project-spine somewhere accessible
git clone https://github.com/YOUR_USERNAME/project-spine.git ~/.project-spine

# In your project directory:
cd your-project
~/.project-spine/install.sh
```

The install script:
- Creates `.spine/` with project tracking files and feature templates
- Installs Codex skills, hooks, and subagent definitions
- Adds a Spine-managed `developer_instructions` block to `.codex/config.toml`
- Creates or extends `AGENTS.md`

## Quick Start

```bash
# Start Codex
codex

# Option A: Define requirements first
> $spine-spec create a spec for user authentication

# Option B: Go straight to planning
> $spine-pwf auth
```

The workflow does not activate automatically. Invoke `$spine-spec` or `$spine-pwf` when you want the framework.

## How It Works

**Plan mode** (Shift+Tab) → design without writing code
**Execute mode** (Shift+Tab again) → same workflow, with explicit worker/reviewer delegation for non-trivial implementation and verification

```
Idea → $spine-spec → spec.md → plan.md → execute → review
       (optional)    (what)     (how)     (code)    (verify)
```

### Files

| File | Purpose | Size |
|---|---|---|
| `.spine/project.md` | Vision, stack, constraints | ≤40 lines |
| `.spine/conventions.md` | Active conventions + decision log | grows slowly |
| `.spine/progress.md` | Feature dashboard | one line per feature |
| `.spine/config.yaml` | Autonomy flag, model preferences | ~20 lines |
| `.spine/features/{slug}/plan.md` | Per-feature plan with phases | 3-7 phases |
| `.spine/features/{slug}/findings.md` | Research and discoveries | updated per 2-Action Rule |
| `.spine/features/{slug}/log.md` | Session log | timestamped entries |
| `.spine/features/{slug}/spec.md` | Requirements (optional) | ≤60 lines |

### Autonomy Levels

| Level | Planning | Execution | Review |
|---|---|---|---|
| **low** | User approves each phase | Pauses after each phase | User requests manually |
| **med** | User approves plan once | Runs without pausing | Auto after final phase |
| **high** | Auto-approved if no conflicts | Delegates bounded work, one writing worker at a time | Auto with summary |

Set in `.spine/config.yaml`:
```yaml
autonomy: med  # low | med | high
```

### Subagents

| Agent | Model | Purpose |
|---|---|---|
| `spine_planner` | gpt-5.4 (high) | Drafts or revises implementation-ready plans |
| `spine_explorer` | gpt-5.4-mini (medium) | Read-only codebase research |
| `spine_worker_simple` | gpt-5.4-mini (medium) | Default plan-scoped implementation |
| `spine_worker_complex` | gpt-5-codex (medium) | Escalation worker for harder phases |
| `spine_reviewer` | gpt-5.4 (high) | Post-implementation verification |

Skills such as `$spine-spec` and `$spine-pwf` run on the main session model.
Only explicit subagent delegation changes models.
Subagent `.toml` files register available agents; the routing policy comes from the shipped instructions in `.codex/config.toml` and `AGENTS.md`.
Typical flow: `spine_planner` drafts the plan, `spine_worker_simple` or `spine_worker_complex` executes approved phases, and `spine_reviewer` verifies the result.

### Hooks

- **SessionStart**: Loads project, conventions, and active feature context on startup/resume
- **PreToolUse / PostToolUse**: Emit structured Bash-scoped reminders for active-plan discipline
- **Stop**: Returns a blocking hook decision until all phases are marked complete

## Customization

Edit `.spine/config.yaml` to change models:
```yaml
models:
  planning: { model: gpt-5.4, effort: high }
  implementation_simple: { model: gpt-5.4-mini, effort: medium }
  implementation_complex: { model: gpt-5-codex, effort: medium }
  review: { model: gpt-5.4, effort: high }
```

Edit `.codex/agents/*.toml` to customize subagent behavior.
Edit the Project Spine managed block in `.codex/config.toml` to change the default delegation policy.

## License

MIT
