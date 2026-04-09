# <!-- BEGIN PROJECT SPINE -->

## Project Spine

This project has the Project Spine workflow framework installed.
It does NOT activate automatically. Invoke explicitly:
- `$spine-spec` — define requirements for a feature
- `$spine-pwf` — plan and implement a feature (uses spine-plan internally)
- `$spine-brainstorm` — explore intent before spec
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
- Plans have two zones separated by a trust boundary:
- **Above** (reviewer reads): decisions, spec+proof with properties, contracts
- **Below** (agent executes): file manifest, implementation steps, test notes, acceptance gate
- Strategy selector: CORRECTNESS | EQUIVALENCE | STRUCTURAL | REGRESSION
- Only CORRECTNESS requires new domain knowledge to review — all others verify preservation
- **Properties are the primary proof artifact** — reviewer validates property statements, agent implements property tests
- Agent does not modify human-authored property statements without re-review
- Reviewer reads top-to-bottom and stops at the trust boundary
- `> [R]:` annotations go in sections above the trust boundary
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
| Planning | gpt-5.4 | high |
| Implementation | gpt-5.4-mini | medium |
| Review | gpt-5.4 | high |
| Quick edit (no spine) | gpt-5.3-codex-spark | medium |
| Deep arch decision | gpt-5.4 | xhigh |

### Delegation rules
- Keep the workflow unchanged: `spine-spec` (optional) → `spine-pwf` → implementation → review
- Main thread owns requirements, approvals, integration decisions, and final user communication
- Keep trivial edits on the main thread
- If stuck or blocked, escalate to user rather than spawning additional agents

### Execution rules (when spine is active)
- SessionStart hook: load `.spine/project.md`, `.spine/conventions.md`, and active feature context on startup/resume
- Stop hook: block session exit until active feature work is actually marked complete
- OpenCode review gate: enforce plan approval before implementation edits (OpenCode only)
- 2-Action Rule: update findings.md after every 2 read/search ops
- 3-Strike errors: diagnose → alternative → rethink → escalate
- Convention check: verify against `.spine/conventions.md`
- Test-first sequence: property tests before implementation code — applies at all autonomy levels
- Property authorship: human-authored or human-validated properties are trusted proof; agent-proposed properties require > [R]: ✓
- spine-plan skill: loaded during planning phase for strategy selection and property extraction

# <!-- END PROJECT SPINE -->
