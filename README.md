# Project Spine

A lightweight AI coding workflow framework for
[OpenAI Codex CLI](https://developers.openai.com/codex/cli).

Combines
[Planning With Files](https://github.com/OthmanAdi/planning-with-files)'
per-feature discipline with project-level tracking, controlled by a single
autonomy flag.

## Why

- Context lost between sessions:
  GSD uses many agents and workflows; PWF uses 3 files per task; Spine uses
  3 files per feature plus session hooks.
- No project-level awareness:
  GSD grows project files unbounded; PWF has none; Spine keeps 3 small
  project-level files.
- Too much / too little ceremony:
  GSD is heavy, PWF is always lightweight, Spine uses the
  `autonomy: low|med|high` flag.
- Architecture drift across features:
  GSD buries conventions in state files, PWF has no cross-feature memory,
  Spine checks conventions before implementation.

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
- Installs Codex skills and hooks
- Creates or extends minimal `AGENTS.md` / `CLAUDE.md` pointers to the
  installed skills

## Quick Start

```bash
# Start Codex
codex

# Option A: Define requirements first
> $spine-spec create a spec for user authentication

# Option B: Go straight to planning
> $spine-pwf auth
```

The workflow does not activate automatically. Invoke `$spine-spec` or
`$spine-pwf` when you want the framework.

## How It Works

**Plan mode** (Shift+Tab) → design without writing code
**Execute mode** (Shift+Tab again) → same workflow, with explicit implementation,
verification, and review stages for non-trivial work

```
Idea → $spine-spec → spec.md → plan.md → implement → verify → review
       (optional)    (what)     (how)     (code)     (evidence) (critique)
```

### Files

- `.spine/project.md`: vision, stack, constraints. On-demand reference.
- `.spine/conventions.md`: active conventions + decision log. On-demand
  reference.
- `.spine/progress.md`: feature dashboard. One line per feature.
- `.spine/config.yaml`: autonomy flag, model preferences. ~20 lines.
- `.spine/features/{slug}/plan.md`: per-feature plan + compact runtime resume
  state. ~1-2 pages.
- `.spine/features/{slug}/findings.md`: research and discoveries. Updated per
  2-Action Rule.
- `.spine/features/{slug}/log.md`: session log. Timestamped entries.
- `.spine/features/{slug}/spec.md`: requirements + invariants. Optional, ≤60
  lines.

### Autonomy Levels

- `low`: user approves key planning choices, execution pauses after each
  implementation step, review is manual.
- `med`: user approves the plan once, execution runs without pausing, review is
  automatic after the final implementation pass.
- `high`: auto-approved if no conflicts, delegates bounded work one writing
  worker at a time, review is automatic with summary.

Set in `.spine/config.yaml`:
```yaml
autonomy: med  # low | med | high
```

### Hooks

- **SessionStart**: Emits compact active-feature resume state on
  startup/resume; deeper `.spine/` files stay on-demand.
- **PreToolUse / PostToolUse**: Emit structured Bash-scoped reminders for
  active-plan discipline.
- **Stop**: Returns a blocking hook decision while acceptance checklists or the
  verification gate remain incomplete

## Customization

Edit `.spine/config.yaml` to set autonomy level and other preferences.

## License

MIT
