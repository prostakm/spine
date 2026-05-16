---
name: spine-verify
description: >
  Run Project Spine's context-minimized verification gate after implementation
  evidence passes. Used by spine-pwf. Does NOT activate automatically.
allow_implicit_invocation: false
---

# Spine Verify

## Entry condition

- Approved plan implementation is complete.
- Planned static rules, scripts, and tests pass locally.
- Acceptance gate evidence is ready to attach to the verifier packet.

## Coverage verification gate

1. Extract verifier packet from approved plan:

   ```bash
   .spine/scripts/extract-verification-context.sh ".spine/features/{slug}/plan.md"
   ```

2. Launch one fresh verifier subagent with only:
   - extracted verifier packet
   - bounded verification evidence from the plan's verification contract
   - touched test/rule files or snippets needed to judge evidence
   - commands run, pass/fail summary, generated-case counts where applicable
   - property-to-evidence mapping

3. Do not give verifier:
   - full `plan.md`
   - implementation strategy
   - `findings.md`
   - freeform implementation narrative
   - broad repository context

4. Ask verifier to judge each property/rule:
   - `covered`
   - `weak`
   - `uncovered`

5. Runtime-enforced properties:
   - list likely surviving runtime mutants
   - identify weak generators, missing boundaries, vacuous assertions

6. Static-enforced properties:
   - list rule/script gaps
   - identify plausible bypasses
   - do not use mutation-style feedback unless behavior is runtime-observable

7. If verifier says `failed` or reports weak/uncovered properties:
   - stop
   - update `## Verification Gate` as `failed`
   - record blocking issues
   - return to `spine-implement` to strengthen rule, script, or test evidence

8. If verifier passes:
   - update `## Verification Gate` with `passed`
   - include last run, verdict, and evidence summary
   - update `## Resume` and `## State`
   - proceed to `spine-closeout`

## Verification Gate format

Maintain the hook-readable marker:

```markdown
## Verification Gate
- Status: passed|failed|pending
- Last run: {timestamp or command}
- Verdict: {summary}
- Blocking issues: {none or list}
```

`## Verification Gate` must be `passed` before review or completion.
