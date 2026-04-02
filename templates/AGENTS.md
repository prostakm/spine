# <!-- BEGIN PROJECT SPINE -->

## Project Spine

This project has the Project Spine workflow framework installed.
It does NOT activate automatically. Invoke explicitly:
- `$spine-spec` — define requirements for a feature
- `$spine-pwf` — plan and implement a feature
- Or say: "use spine", "spine plan", "spine spec"

Without explicit invocation, work normally — no planning files, no gates, no hooks.

### When invoked, the workflow has two hard gates:

```
$spine-spec ──► STOP ──► $spine-pwf ──► STOP ──► implement ──► review
                "plan when ready"       user reviews plan.md
                                        inline > [R]: comments
                                        marks APPROVED
```

- After spec: STOP. Do NOT auto-plan.
- After plan: STOP. Do NOT code until APPROVED.
- Gates apply at all autonomy levels.

### Context files (read when spine is invoked)
- `.spine/project.md` — vision, stack, constraints
- `.spine/conventions.md` — coding conventions, decision log
- `.spine/progress.md` — feature status dashboard
- `.spine/config.yaml` — autonomy level, model preferences

### Plan detail
- File paths, types/schemas, function signatures, pseudocode (non-trivial only)
- Edge cases, test case names, verify command
- Phase split only when natural — single-plan is fine
- See `docs/EXAMPLE-PLAN.md` for style

### Inline plan review
User edits plan.md directly with `> [R]:` comments next to relevant content.
On "address comments": apply changes, answer as `> [A]:`, mark ✓.
On `> [R]: APPROVED`: proceed to implementation.

### Decision involvement (from .spine/config.yaml)

| | low | med | high |
|---|---|---|---|
| Planning | ASK every choice | ASK arch/deps/APIs | Decide, show rationale |
| Implementation | ASK any deviation | ASK plan deviation + 3-Strike | ASK conflicts only |
| Plan approval | Required | Required | Required |

### Model routing

| Phase | Model | Effort |
|---|---|---|
| Spec | gpt-5.4 | high |
| Exploration (subagent) | gpt-5.4-mini | medium |
| Planning | gpt-5.4 | high |
| Implementation (default subagent) | gpt-5.4-mini | medium |
| Implementation (complex subagent) | gpt-5-codex | medium |
| Review (subagent) | gpt-5.4 | high |
| Quick edit (no spine) | gpt-5.3-codex-spark | medium |
| Deep arch decision | gpt-5.4 | xhigh |

### Delegation rules
- Keep the workflow unchanged: `spine-spec` (optional) → `spine-pwf` → implementation → review
- Main thread owns requirements, approvals, integration decisions, and final user communication
- Skills do not change models; only explicit subagent delegation changes models
- Agent `.toml` files only register available subagents; they do not auto-route work by themselves
- Explicitly spawn `spine_worker_simple` for approved non-trivial implementation work
- Escalate to `spine_worker_complex` only for cross-cutting, refactor-heavy, migration-like, or failure-prone phases
- Keep `spine_worker` as a backward-compatible alias of the simple worker
- Use `spine_explorer` only for read-heavy prep when extra research materially helps
- Explicitly spawn `spine_reviewer` after implementation completes
- Keep trivial edits on the main thread
- Only one writing subagent at a time
- If subagent tools are unavailable, continue on the main thread and state that fallback explicitly

### Execution rules (when spine is active)
- SessionStart hook: load `.spine/project.md`, `.spine/conventions.md`, and active feature context on startup/resume
- PreToolUse/PostToolUse hooks: Bash-scoped structured reminders in current Codex runtime
- 2-Action Rule: update findings.md after every 2 read/search ops
- 3-Strike errors: diagnose → alternative → rethink → escalate
- Convention check: verify against `.spine/conventions.md`

# <!-- END PROJECT SPINE -->
