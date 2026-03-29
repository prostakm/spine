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
- Creates or extends `AGENTS.md`

## Quick Start

```bash
# Start Codex
codex

# Option A: Define requirements first
> $spine-spec create a spec for user authentication

# Option B: Go straight to planning
> Plan and implement a user authentication system

# The workflow activates automatically for complex tasks
```

## How It Works

**Plan mode** (Shift+Tab) → design without writing code
**Execute mode** (Shift+Tab again) → PWF hooks keep you on track

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
| **high** | Auto-approved if no conflicts | Parallel phases | Auto with summary |

Set in `.spine/config.yaml`:
```yaml
autonomy: med  # low | med | high
```

### Subagents

| Agent | Model | Purpose |
|---|---|---|
| `spine_explorer` | gpt-5.4-mini (medium) | Read-only codebase research |
| `spine_worker` | gpt-5.3-codex (high) | Plan-scoped implementation |
| `spine_reviewer` | gpt-5.4 (high) | Post-implementation verification |

### Hooks

- **PreToolUse**: Injects first 30 lines of current plan before every tool call
- **PostToolUse**: Reminds to update phase status
- **Stop**: Blocks until all phases are marked complete

## Customization

Edit `.spine/config.yaml` to change models:
```yaml
models:
  implementation: { model: gpt-5.4-mini, effort: medium }  # cheaper
  review: { model: gpt-5.4, effort: xhigh }                # thorough
```

Edit `.codex/agents/*.toml` to customize subagent behavior.

## License

MIT
