---
dependencies: []
dependents: []
---

# Spec: pi-spine-plugin

**Role:** architect

## Problem
Project Spine enforces plan-review gates mechanically on OpenCode (JS plugin),
Codex (shell hooks), and Claude Code (shell hooks). Pi has zero — gates are
prose instructions in skill files that the LLM can skip.

The `opencode-spine.js` plugin already has all the gate logic (~400 lines of
pure functions: `planIsApproved`, `markPlanApproved`, `markSpecApproved`,
`collectToolTargets`, `bashAllowed`, `surfaceContext`, etc.). Pi's extension
API (`pi.on("tool_call")`, `pi.on("session_start")`, etc.) is conceptually the
same shape as OpenCode's `tool.execute.before` / `session.created`.

## Requirements
- REQ-1: Extract core logic from `opencode-spine.js` into a shared module
  (`spine-core.js`) — pure functions, no OpenCode or Pi imports
- REQ-2: `opencode-spine.js` imports from `spine-core.js`, wraps in
  `export const SpinePlugin` — thin adapter only
- REQ-3: New `pi/spine.ts` Pi extension imports from the same `spine-core.js`,
  wraps in `export default function spinePiPlugin(pi: ExtensionAPI)` —
  thin adapter only
- REQ-4: `install.sh` copies `spine-core.js` + `pi/spine.ts` + `opencode-spine.js`
  to a shared location, and adds Pi extension to the project's `.pi/`
- REQ-5: Pi session-start surfaces context via `ctx.ui.notify` or console
- REQ-6: Approval mirroring works on Pi — user says "approved" → auto-mirrors
  into plan.md/spec.md via `before_agent_start` scan

## Boundaries
- NOT: replacing Codex/Claude bash hooks — those stay
- NOT: a general-purpose Pi hook framework — scoped to Spine gates
- DO NOT: duplicate `planIsApproved`, `markPlanApproved`, `allowedPendingPaths`,
  `bashAllowed`, etc. in both adapters
- DO NOT: require `client.session.message()` RPC — Pi doesn't have that;
  use `before_agent_start` + message content scanning instead

## Inputs & Outputs
- In: `.spine/features/{slug}/plan.md` state
- Out: tool-call block/allow (`{ block: true, reason: "..." }`); session
  context notification; plan.md/spec.md approval mirror writes

## Change type
- Type: infrastructure

## Pi Extension API (confirmed from existing extensions)

### Entry point
```ts
import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
export default function spinePiPlugin(pi: ExtensionAPI): void { ... }
```
Extensions live in `~/.pi/agent/extensions/*.ts` (global) or
`.pi/extensions/*.ts` (project root). Both auto-discovered. Files are `.ts`,
transpiled at load time by jiti.

### Events available
| Event | Signature | Use |
|---|---|---|
| `tool_call` | `(event: { toolName, input }, ctx?) => { block, reason }?` | Gate enforcement — block writes when plan unapproved |
| `session_start` | `(_event, ctx: { cwd, hasUI, ui, sessionManager }) => void` | Surface context on resume |
| `before_agent_start` | `() => { message?: { customType, content, display? } }?` | Inject context + scan last user message for "approved" |

### Tool-call blocking shape
```ts
return { block: true, reason: "[spine] Plan review gate is pending..." };
```
Return `undefined` (or nothing) to allow. Block messages appear in the TUI.

### Tool input shapes (confirmed from policy-engine)
- `event.toolName`: `"write"`, `"edit"`, `"bash"`, `"read"`, `"ls"`, etc.
- `event.input.path`: file path for write/edit (string)
- `event.input.command`: command string for bash
- `event.input.edits`: array of `{ file_path?, oldText, newText }` for edit tool
- `event.input.file_path`: single file path (write tool)

### Context (ctx) shape
- `ctx.cwd`: current project directory (string)
- `ctx.hasUI`: boolean
- `ctx.ui.notify(message, level?)`: show notification
- `ctx.ui.setStatus(key, text?)`: footer status
- `ctx.sessionManager.getEntries()`: session entries for state restore

### Approval-mirroring approach
Pi does not have `message.updated` RPC (OpenCode-specific). Alternative:
`before_agent_start` fires before each turn. Scan incoming messages via
`pi.getMessages()` or simpler: at `tool_call` time, check if plan is approved
(lazy — no auto-mirror yet). For auto-mirror, we can hook into the fact that
Pi remembers the last user message through the session. Simpler approach:
don't auto-mirror; rely on the plan.md `## State` + `## Review Gate` blocks
being updated by the LLM when it follows the spine-pwf protocol. The
gate-keeper only blocks on `planIsApproved()` which checks `R> APPROVED` or
`Review Gate → Status: approved`.

This means REQ-6 (approval mirroring) is **lower priority** — the critical
path is REQ-5 (tool-call blocking). Mirroring is nice-to-have and can be
done via `before_agent_start` scanning for `/approved/i` in the last user
message.

## Acceptance Criteria
- [ ] `spine-core.js` extracted from `opencode-spine.js` — all pure functions,
  no platform imports
- [ ] `opencode-spine.js` becomes thin adapter (< 50 lines of remaining code)
- [ ] `pi/spine.ts` imports `spine-core.js`, registers `tool_call` handler
  that blocks writes when plan is unapproved
- [ ] `pi/spine.ts` registers `session_start` handler that surfaces active feature
- [ ] `install.sh` places all files correctly
- [ ] Manual test: spec approved, plan not approved → `write src/main.ts` blocked
  → approve plan → `write src/main.ts` allowed

## Flows
- **Gate enforcement**: `tool_call` event → `readSlug(cwd)` → `planIsApproved(plan)` →
  if pending, `collectToolTargets` checks targets → blocks non-spine targets
- **Session resume**: `session_start` → `readSlug(cwd)` → `pickResumeFile` →
  `ctx.ui.notify("[spine] slug | phase | gate")`
- **Approval mirroring** (async, lower priority): `before_agent_start` →
  scan last user message → if `approved` → `markPlanApproved`/`markSpecApproved`

## Invariants
- structural: `planIsApproved`, `collectToolTargets`, `bashAllowed`, `readSlug`,
  `pickResumeFile` live in one file (`spine-core.js`) imported by both adapters
  - Enforcement hint: lint (no duplication of these function bodies)
- preservation: Pi gate behavior matches OpenCode gate behavior for same plan
  states
  - Enforcement hint: runtime (shared `spine-core.js` module, manual test)
- structural: Pi extension is a single `.ts` file in `.pi/extensions/`
  - Enforcement hint: static (install.sh copies file)
- structural: `spine-core.js` has zero platform imports (`fs` and `path` are
  the only Node builtins used — both available in Pi's jiti runtime)
  - Enforcement hint: lint (ban `@mariozechner/*` imports in core)

## File Layout
```
hooks/
  spine-core.js          ←  NEW: extracted pure functions
  opencode-spine.js      ←  MODIFIED: thin adapter, imports spine-core.js
  pre-tool-use.sh        ←  UNCHANGED
  stop.sh                ←  UNCHANGED
  session-start.sh       ←  UNCHANGED
  hooks.json             ←  UNCHANGED
pi/
  spine.ts               ←  NEW: Pi extension adapter, imports ../hooks/spine-core.js
```

## Open Questions
- **Pi extension discovery**: does `.pi/extensions/` work in project root?
  From the existing extensions pattern, both `~/.pi/agent/extensions/` (global)
  and `.pi/extensions/` (project root) are auto-discovered. We'll use
  `.pi/extensions/spine.ts`.
- **jiti transpilation**: Pi uses jiti to load `.ts` files directly. Our
  `spine-core.js` is plain JS (Node ESM) — jiti handles this fine.
- **Approval mirroring**: lower priority. Core blocker is tool-call gate
  enforcement. Mirroring can be added later via `before_agent_start`.

## Resume
- Source: spec
- Phase: spec
- Gate: pending
- Current Slice: spec complete — all Pi API unknowns resolved from existing extensions
- Next Step: approve the spec or request changes before planning
- Open Questions: none — Pi API fully understood from plan-mode + policy-engine extensions
- Files in Play: `.spine/features/pi-spine-plugin/spec.md`
