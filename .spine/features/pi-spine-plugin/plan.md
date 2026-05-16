# Feature: pi-spine-plugin

> **Story:**
> Extract gate-enforcement logic from `opencode-spine.js` into a shared `spine-core.js` module.
> Create a generic Pi extension that loads existing OpenCode plugins from
> `.opencode/plugins/*.js` and bridges their hook system into Pi's extension API.
> No duplicated adapters — one bridge works for any OpenCode plugin.

## Status
- **Status:** REVIEW
- **Strategy:** STRUCTURAL
- **Risk:** LOW — pure refactor of existing logic, no new gate behavior, new code is thin adapter
- **Scope:** Extract `spine-core.js` from `opencode-spine.js`; create `pi/spine.ts`;
  update `install.sh`

## System view

```text
            spine-core.js (pure functions)
                 │
                 ▼ import
          opencode-spine.js
          (SpinePlugin export)
                 │
                 ▼ dynamically loaded by
          pi/opencode-bridge.ts (NEW)
          (generic bridge — no spine knowledge)
                 │
          pi.on("tool_call") → plugin["tool.execute.before"]
          pi.on("session_start") → plugin["session.created"]

[UNCHANGED] pre-tool-use.sh           ← Codex
[UNCHANGED] stop.sh                   ← Codex/Claude
[UNCHANGED] session-start.sh          ← Codex
            hooks.json                ← Codex/Claude
```

## Behaviors

- Flow A — gate enforcement (write path)
- Flow B — session resume (read path)

System-wide invariants:

- **P1** — `planIsApproved` returns same answer for same plan.md regardless of platform
  - holds: `spine-core.js` → `planIsApproved(content)`
  - test: manual check that both adapters use the same exported function
  - never: reimplement `planIsApproved` in either adapter
  - never: add platform-specific approval checks

## Flow A — gate enforcement

```text
tool call → adapter → spine-core.js → check slug? plan exists? approved?
                                    → collect targets → block/allow
```

### A.1 — Extract core functions from opencode-spine.js

> **Step intent:** Move all pure functions (no OpenCode API imports) from
> `opencode-spine.js` into a new `spine-core.js` module. Each function keeps
> the same name, same signature, same export. The OpenCode plugin becomes a
> thin wrapper that imports from `spine-core.js`.

- 🔴 **D1** — export style
  <details><summary>chose: named exports</summary>

  - over: default export with destructuring
  - why not: harder to tree-shake by name; named exports document the API surface explicitly
  - consequence: both adapters `import { planIsApproved, readSlug, ... } from "./spine-core.js"`
  </details>

- **R1** — `spine-core.js` has zero OpenCode or Pi imports
  - holds: every function imported by at least one adapter
  - test: `grep "@mariozechner\|client\.session" spine-core.js` → zero hits
  - never: import `client`, `ExtensionAPI`, or any platform-specific type in core

- **P2** — function signatures unchanged
  - holds: all currently-exported helpers (readSlug, planPath, specPath, readPlan, pickResumeFile,
    normalizePath, fieldValue, extractSection, planIsApproved, setFieldValue, setSectionStatus,
    markPlanApproved, markSpecApproved, writeIfChanged, collectNestedPaths, extractPatchTargets,
    collectToolTargets, allowedPendingPaths, allTargetsAllowedWhilePending, approvalTarget,
    extractMessageText, bashAllowed)
  - test: `opencode-spine.js` adapter code calls same function names
  - never: change parameter order or return types during extraction

- → impl: [I1](#i1)

### A.2 — Rewrite opencode-spine.js as thin adapter

> **Step intent:** Replace the 370+ lines of helper functions in
> `opencode-spine.js` with imports from `spine-core.js`. Keep only the
> OpenCode-specific plugin wrapper: `export const SpinePlugin`, the
> `event` handler, `tool.execute.before`, and `session.created`.

- 🔴 **D2** — remove local helpers
  <details><summary>chose: delete all functions that moved to spine-core.js</summary>

  - over: keep them locally and export from spine-core as well
  - why not: two sources of truth, drift risk
  - consequence: opencode-spine.js is ~50 lines total (plugin wrapper + imports)
  </details>

- **R2** — plugin behavior unchanged after refactor
  - holds: all three handlers (event, tool.execute.before, session.created) call same core functions
  - test: diff the handler logic — should be identical minus `import` vs `function` definitions
  - never: change control flow in handlers

- → impl: [I2](#i2)

### A.3 — Create pi/spine.ts Pi extension

> **Step intent:** New TypeScript file that imports from `spine-core.js` and
> wraps the gate logic in Pi's extension API: `pi.on("tool_call")` for blocking,
> `pi.on("session_start")` for context surfacing, `pi.on("before_agent_start")`
> for approval mirroring.

- 🔴 **D3** — tool-call blocking via `pi.on("tool_call")`
  <details><summary>chose: use `event.toolName` + `event.input.path/command/edits`</summary>

  - over: `pi.on("tool_execute.before")` — doesn't exist
  - why not: `pi.on("before_tool_call")` — also doesn't exist;
    CHANGELOG confirms `tool_call` is the pre-execution hook
  - consequence: handler receives `{ toolName, input }`,
    returns `{ block: true, reason }` or `undefined`
  </details>

- **P3** — Pi gate matches OpenCode gate for same plan states
  - holds: both adapters call `planIsApproved(content)` and
    `allTargetsAllowedWhilePending(tool, args, root, slug)`
  - test: manual — same feature slug, same plan.md → same block/allow result
  - never: use different approval-check logic in Pi adapter

- **P4** — `spine-core.js` imports use relative path from Pi extension
  - holds: `pi/spine.ts` lives at `pi/spine.ts`, imports `../hooks/spine-core.js`
  - test: `cat pi/spine.ts | head` confirms import path
  - pattern: `import { ... } from "../hooks/spine-core.js"`

- **D4** — approval mirroring: lazy only
  <details><summary>chose: no auto-mirror in initial version</summary>

  - over: `before_agent_start` scan of last user message for
    "approved" → write to plan.md
  - why not: complex, fragile, requires parsing message content
    from Pi's internal message store
  - consequence: plan approval must be manual (`R> APPROVED` in plan.md) —
    same as Codex/Claude bash hooks
  </details>

- → impl: [I3](#i3)

## Flow B — session resume

```text
session_start → readSlug(cwd) → pickResumeFile → notify context
```

### B.1 — Surface context on session start

> **Step intent:** When Pi starts or resumes a session in a project with an
> active spine feature, show a compact status line via `ctx.ui.notify()` or
> `ctx.ui.setStatus()`.

- **R3** — context shown exactly once per session
  - holds: `session_start` fires once
  - test: start Pi in a spine project → see `[spine] slug | phase | gate` notification
  - never: emit on every turn

- **P5** — context format matches OpenCode
  - holds: same `pickResumeFile`, same field extraction
  - test: compare console output format
  - never: omit gate status from Pi context line

- → impl: [I4](#i4)

## Acceptance matrix

| ID | Invariant / rule | Test | Strategy |
|----|------------------|------|----------|
| P1 | `planIsApproved` identical across platforms | grep import in both adapters | lint |
| R1 | `spine-core.js` zero platform imports | `grep` | lint |
| P2 | Function signatures unchanged | diff opencode-spine.js handler code | review |
| R2 | Plugin behavior unchanged | manual smoke test | runtime |
| P3 | Pi gate = OpenCode gate | manual same-state test | runtime |
| P4 | Pi import path correct | `cat pi/spine.ts` | lint |
| P5 | Context format matches | visual check | runtime |

---

<!-- ═══════════════════════════════════════════════════════ -->
<!-- TRUST BOUNDARY — reviewer stops here                   -->
<!-- ═══════════════════════════════════════════════════════ -->

## Agent instructions

### Verification packet

- Strategy: `STRUCTURAL`
- Properties: `P1`, `P2`, `P3`, `P4`, `P5`
- Rules: `R1`, `R2`, `R3`
- Verifier constraints: check that `spine-core.js` exports are used by both adapters; check
  that no function bodies are duplicated; check import paths are correct

### File manifest

```text
hooks/
├── spine-core.js              [C] → I1
├── opencode-spine.js          [M] → I2
├── pre-tool-use.sh            [UNCHANGED]
├── stop.sh                    [UNCHANGED]
├── session-start.sh           [UNCHANGED]
└── hooks.json                 [UNCHANGED]
pi/
└── spine.ts                   [C] → I3, I4
install.sh                     [M] → I5
```

### Implementation

#### I1 — Extract spine-core.js <a id="i1"></a>

- **Intent:** Create `hooks/spine-core.js` containing all pure functions from `opencode-spine.js`,
  exported as named exports. Keep every function body identical.
- **References:** P1, P2, R1
- **Critical:** 🔴

```diff
--- /dev/null
+++ b/hooks/spine-core.js
@@ -0,0 +1,370 @@
+// Project Spine — core gate-enforcement logic
+// Platform-agnostic pure functions shared by OpenCode and Pi adapters.
+
+import { readFileSync, existsSync, writeFileSync } from "fs"
+import { join } from "path"
+
+export function readSlug(root) {
+  const f = join(root, ".spine", "active-feature")
+  if (!existsSync(f)) return null
+  return readFileSync(f, "utf8").trim() || null
+}
+
+export function planPath(root, slug) {
+  return join(root, ".spine", "features", slug, "plan.md")
+}
+
+export function specPath(root, slug) {
+  return join(root, ".spine", "features", slug, "spec.md")
+}
+
+export function readPlan(p) {
+  return existsSync(p) ? readFileSync(p, "utf8") : null
+}
+
+export function normalizePath(filePath, root) {
+  if (!filePath) return null
+  return filePath.startsWith("/") ? filePath : join(root, filePath)
+}
+
+export function fieldValue(content, heading, field) {
+  const lines = content.split("\n")
+  const head = `## ${heading}`
+  const pat = new RegExp(`^\\s*-\\s*${field}:\\s*(.*)$`)
+  let inSection = false
+  let waiting = false
+  for (const line of lines) {
+    if (line === head) { inSection = true; continue }
+    if (inSection && /^## /.test(line)) break
+    if (!inSection) continue
+    const m = line.match(pat)
+    if (m) {
+      if (m[1].trim()) return m[1].trim()
+      waiting = true
+      continue
+    }
+    if (waiting) {
+      if (/^\s+[^\-`0-9]/.test(line)) return line.trim()
+      if (!/^\s*$/.test(line)) break
+    }
+  }
+  return null
+}
+
+export function extractSection(content, heading) {
+  const lines = content.split("\n")
+  const head = `## ${heading}`
+  let inSection = false
+  const out = []
+  for (const line of lines) {
+    if (line === head) { inSection = true; continue }
+    if (inSection && /^## /.test(line)) break
+    if (inSection) out.push(line)
+  }
+  return out.join("\n").trim()
+}
+
+export function planIsApproved(content) {
+  if (/^R>\s*APPROVED(\s|$)/m.test(content)) return true
+  if (/^> \[R\]:\s*APPROVED(\s|$)/m.test(content)) return true
+  return fieldValue(content, "Review Gate", "Status") === "approved"
+}
+
+export function pickResumeFile(root, slug) {
+  const plan = planPath(root, slug)
+  const spec = specPath(root, slug)
+  const planContent = readPlan(plan)
+  const specContent = readPlan(spec)
+
+  if (!planContent && !specContent) return null
+
+  if (planContent) {
+    const preferred = fieldValue(planContent, "Resume", "Source")
+    if (preferred === "spec" && specContent) {
+      return { source: "spec", path: spec, content: specContent }
+    }
+    return { source: "plan", path: plan, content: planContent }
+  }
+
+  return { source: "spec", path: spec, content: specContent }
+}
+
+export function setFieldValue(content, heading, field, value) {
+  const lines = content.split("\n")
+  const head = `## ${heading}`
+  const pat = new RegExp(`^\\s*-\\s*${field}:\\s*(.*)$`)
+  let inSection = false
+  let insertAt = lines.length
+  for (let i = 0; i < lines.length; i++) {
+    if (lines[i] === head) {
+      inSection = true
+      insertAt = i + 1
+      continue
+    }
+    if (inSection && /^## /.test(lines[i])) {
+      let at = i
+      while (at > 0 && lines[at - 1] === "") at--
+      lines.splice(at, 0, `- ${field}: ${value}`)
+      return lines.join("\n")
+    }
+    if (inSection && pat.test(lines[i])) {
+      lines[i] = `- ${field}: ${value}`
+      return lines.join("\n")
+    }
+    if (inSection) insertAt = i + 1
+  }
+  if (inSection) {
+    let at = insertAt
+    while (at > 0 && lines[at - 1] === "") at--
+    lines.splice(at, 0, `- ${field}: ${value}`)
+    return lines.join("\n")
+  }
+  return content
+}
+
+export function setSectionStatus(content, heading, value) {
+  const lines = content.split("\n")
+  const head = `## ${heading}`
+  let inSection = false
+  for (let i = 0; i < lines.length; i++) {
+    if (lines[i] === head) {
+      inSection = true
+      continue
+    }
+    if (inSection && /^## /.test(lines[i])) {
+      lines.splice(i, 0, `Status: ${value}`)
+      return lines.join("\n")
+    }
+    if (inSection && /^Status:\s*/.test(lines[i])) {
+      lines[i] = `Status: ${value}`
+      return lines.join("\n")
+    }
+  }
+  return inSection ? [...lines, `Status: ${value}`].join("\n") : content
+}
+
+export function markPlanApproved(content) {
+  let next = setFieldValue(content, "Review Gate", "Status", "approved")
+  const hasApprovalMarker =
+    /^R>\s*APPROVED(\s|$)/m.test(next) || /^> \[R\]:\s*APPROVED(\s|$)/m.test(next)
+  if (!hasApprovalMarker && next.includes("\n## Review Gate")) {
+    next = next.replace("\n## Review Gate", "\nR> APPROVED\n\n## Review Gate")
+  }
+  return next
+}
+
+export function markSpecApproved(content) {
+  let next = content
+  next = setFieldValue(next, "Status", "Brainstorm", "complete")
+  next = setFieldValue(next, "Status", "Design", "approved")
+  next = setFieldValue(next, "Status", "Spec", "approved")
+  return setSectionStatus(next, "Proposed Design", "approved")
+}
+
+export function writeIfChanged(filePath, next) {
+  if (!next || !existsSync(filePath)) return
+  const prev = readFileSync(filePath, "utf8")
+  if (prev !== next) writeFileSync(filePath, next)
+}
+
+export function collectNestedPaths(value, out = new Set()) {
+  if (!value || typeof value !== "object") return out
+  if (Array.isArray(value)) {
+    for (const item of value) collectNestedPaths(item, out)
+    return out
+  }
+  for (const [key, nested] of Object.entries(value)) {
+    if (["filePath", "file_path", "path"].includes(key) && typeof nested === "string") {
+      out.add(nested)
+      continue
+    }
+    collectNestedPaths(nested, out)
+  }
+  return out
+}
+
+export function extractPatchTargets(patchText) {
+  if (!patchText) return []
+  const out = []
+  const patterns = [
+    /^\*\*\* (?:Add|Update|Delete) File: (.+)$/gm,
+    /^\*\*\* Move to: (.+)$/gm,
+  ]
+  for (const pattern of patterns) {
+    for (const match of patchText.matchAll(pattern)) {
+      out.push(match[1].trim())
+    }
+  }
+  return out
+}
+
+export function collectToolTargets(tool, args) {
+  if (tool === "apply_patch") {
+    const patchTargets = extractPatchTargets(args?.patchText ?? args?.patch_text ?? "")
+    if (patchTargets.length > 0) return patchTargets
+  }
+  return [...collectNestedPaths(args)]
+}
+
+export function allowedPendingPaths(root, slug) {
+  return new Set([planPath(root, slug), specPath(root, slug)])
+}
+
+export function allTargetsAllowedWhilePending(tool, args, root, slug) {
+  const targets = collectToolTargets(tool, args)
+  if (targets.length === 0) return false
+  const allowed = allowedPendingPaths(root, slug)
+  return targets.every(target => allowed.has(normalizePath(target, root)))
+}
+
+export function approvalTarget(text) {
+  const normalized = text.trim().toLowerCase()
+  if (!normalized) return null
+  if (/^(approved|i approve|approve)\.?$/.test(normalized)) return "generic"
+  if (/^(plan approved|i approve the plan|i approve plan)\.?$/.test(normalized)) return "plan"
+  if (/^(spec approved|i approve the spec|i approve spec)\.?$/.test(normalized)) return "spec"
+  return null
+}
+
+export function extractMessageText(parts) {
+  return parts
+    .filter(part => part?.type === "text" && !part.synthetic && !part.ignored)
+    .map(part => part.text)
+    .join("\n")
+    .trim()
+}
+
+const SHELL_OPS = [">", "<", "|", ";", "$(", "`", "&&", "||"]
+
+const READ_ONLY_PREFIXES = [
+  "cat ", "sed ", "rg ", "grep ", "find ", "ls ", "head ", "tail ",
+  "wc ", "nl ", "awk ", "cut ", "sort ", "uniq ", "tr ", "stat ",
+  "git status", "git diff", "git show", "git rev-parse",
+  "git branch", "git log", "git blame",
+]
+
+const READ_ONLY_SCRIPTS = [
+  ".spine/scripts/validate-plan.sh",
+  "scripts/validate-plan.sh",
+  ".spine/scripts/validate-spine-doc.sh",
+  "scripts/validate-spine-doc.sh",
+  ".spine/scripts/extract-verification-context.sh",
+  "scripts/extract-verification-context.sh",
+]
+
+function stripWrappingQuotes(token) {
+  if (!token || token.length < 2) return token
+  const first = token[0]
+  const last = token[token.length - 1]
+  if ((first === '"' || first === "'") && first === last) {
+    return token.slice(1, -1)
+  }
+  return token
+}
+
+function normalizeCommandWord(token) {
+  const unquoted = stripWrappingQuotes(token.trim())
+  return unquoted.replace(/^\.\//, "")
+}
+
+function tokenizeShellCommand(cmd) {
+  return cmd.match(/"[^"]*"|'[^']*'|\S+/g) ?? []
+}
+
+function matchesReadOnlyScript(words) {
+  if (words.length === 0) return false
+
+  const [first, second] = words
+  const firstWord = normalizeCommandWord(first)
+  const secondWord = normalizeCommandWord(second ?? "")
+
+  if (READ_ONLY_SCRIPTS.includes(firstWord)) return true
+  if (["bash", "sh"].includes(firstWord) && READ_ONLY_SCRIPTS.includes(secondWord)) {
+    return true
+  }
+
+  return false
+}
+
+export function bashAllowed(cmd) {
+  if (!cmd) return false
+  if (SHELL_OPS.some(op => cmd.includes(op))) return false
+
+  const words = tokenizeShellCommand(cmd)
+  if (matchesReadOnlyScript(words)) return true
+
+  const normalized = words.map(normalizeCommandWord).join(" ")
+  return READ_ONLY_PREFIXES.some(
+    prefix => normalized === prefix.trim() || normalized.startsWith(prefix)
+  )
+}
```

#### I2 — Rewrite opencode-spine.js as thin adapter <a id="i2"></a>

- **Intent:** Replace all helper function definitions with imports from `spine-core.js`.
  Keep plugin wrapper and three handlers unchanged.
- **References:** P1, P2, R1, R2
- **Critical:** 🔴

```diff
--- a/hooks/opencode-spine.js
+++ b/hooks/opencode-spine.js
@@ -1,380 +1,50 @@
 // Project Spine — OpenCode plugin
 // Enforces the plan review gate before edits and surfaces context on session start.
 // Explicit chat approval is mirrored into the active plan/spec file.
 // Installed to .opencode/plugins/spine.js in your project by install.sh.
 
-import { readFileSync, existsSync, writeFileSync } from "fs"
-import { join } from "path"
+import {
+  readSlug,
+  planPath,
+  specPath,
+  readPlan,
+  pickResumeFile,
+  planIsApproved,
+  markPlanApproved,
+  markSpecApproved,
+  writeIfChanged,
+  allTargetsAllowedWhilePending,
+  approvalTarget,
+  extractMessageText,
+  bashAllowed,
+  fieldValue,
+  extractSection,
+} from "./spine-core.js"
 
 // ── Plugin ────────────────────────────────────────────────────────────────────
 
 export const SpinePlugin = async ({ directory, client }) => {
   const root = directory
```

The rest of the file (plugin wrapper + three handlers) stays identical — only the helper
function bodies above the plugin wrapper are replaced with imports.

#### I3 — Create pi/spine.ts <a id="i3"></a>

- **Intent:** New Pi extension that imports core functions and registers `tool_call`
  and `session_start` handlers matching OpenCode behavior.
- **References:** P3, P4, D3, D4
- **Critical:** 🔴

```diff
--- /dev/null
+++ b/pi/spine.ts
@@ -0,0 +1,80 @@
+// Project Spine — Pi extension
+// Enforces the plan review gate before edits and surfaces context on session start.
+// Installed to .pi/extensions/spine.ts in your project by install.sh.
+
+import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
+import {
+  readSlug,
+  planPath,
+  specPath,
+  readPlan,
+  pickResumeFile,
+  planIsApproved,
+  fieldValue,
+  extractSection,
+  allTargetsAllowedWhilePending,
+  bashAllowed,
+} from "../hooks/spine-core.js";
+
+export default function spinePiPlugin(pi: ExtensionAPI): void {
+  // ── Gate enforcement — block writes while plan is unapproved ──
+  pi.on("tool_call", async (event: { toolName: string; input: Record<string, unknown> }) => {
+    const slug = readSlug(process.cwd());
+    if (!slug) return;
+
+    const plan = planPath(process.cwd(), slug);
+    const content = readPlan(plan);
+    if (!content) return;
+    if (planIsApproved(content)) return;
+
+    const toolName = event.toolName.toLowerCase();
+    const args = event.input as Record<string, unknown>;
+
+    // Block write tools targeting non-.spine files
+    if (["write", "edit", "apply_patch"].includes(toolName)) {
+      if (!allTargetsAllowedWhilePending(toolName, args, process.cwd(), slug)) {
+        return {
+          block: true,
+          reason:
+            `[spine] Plan review gate is pending for '${slug}'. ` +
+            `Only edits to ${plan} or ${specPath(process.cwd(), slug)} ` +
+            `are allowed until approval is recorded. ` +
+            `Record approval in ${plan} or mark R> APPROVED.`,
+        };
+      }
+    }
+
+    // Block non-read-only bash
+    if (toolName === "bash") {
+      const cmd = (args.command as string) ?? "";
+      if (!bashAllowed(cmd)) {
+        return {
+          block: true,
+          reason:
+            `[spine] Plan review gate is pending for '${slug}'. ` +
+            `Only read-only commands are allowed until approval is recorded in ${plan}.`,
+        };
+      }
+    }
+  });
+
+  // ── Session resume — surface active feature context ──
+  pi.on("session_start", async (_event: unknown, ctx: ExtensionContext) => {
+    const slug = readSlug(ctx.cwd);
+    if (!slug) return;
+
+    const resume = pickResumeFile(ctx.cwd, slug);
+    if (!resume) return;
+
+    const phase = fieldValue(resume.content, "Resume", "Phase")
+      ?? (resume.source === "plan" ? fieldValue(resume.content, "State", "Phase") : null)
+      ?? (resume.source === "spec" ? "spec" : null)
+      ?? "unknown";
+    const gate = fieldValue(resume.content, "Resume", "Gate")
+      ?? (resume.source === "plan"
+        ? (planIsApproved(resume.content)
+          ? "approved"
+          : fieldValue(resume.content, "Review Gate", "Status"))
+        : "pending")
+      ?? "pending";
+
+    const msg = `[spine] ${slug} | source: ${resume.source} | phase: ${phase} | gate: ${gate}`;
+
+    if (ctx.hasUI) {
+      ctx.ui.notify(msg, "info");
+    }
+  });
+}
```

#### I4 — Update install.sh for Pi extension <a id="i4"></a>

- **Intent:** Add Pi extension install steps to `install.sh`: create `pi/` directory,
  copy `pi/spine.ts`, create `.pi/extensions/` in target project, copy `spine-core.js`.
- **References:** P4
- **Critical:** 🟡

```diff
--- a/install.sh
+++ b/install.sh
@@ -630,6 +630,15 @@
 sync_managed_file "$SCRIPT_DIR/hooks/hooks.json" ".codex/hooks.json"
 remove_if_exists ".codex/hooks/hooks.json"
 
+# ── Step 4b: Copy Pi extension ──
+mkdir -p "$PROJECT_ROOT/.pi/extensions"
+sync_managed_file "$SCRIPT_DIR/pi/spine.ts" "$PROJECT_ROOT/.pi/extensions/spine.ts"
+sync_managed_file "$SCRIPT_DIR/hooks/spine-core.js" "$PROJECT_ROOT/.pi/extensions/spine-core.js"
+info "Pi extension: .pi/extensions/spine.ts"
+
 # ── Step 5: Handle AGENTS.md ──
```

Also update the install summary to mention Pi:

```diff
@@ -790,6 +799,7 @@
 echo "    .claude/settings.json      ← PreToolUse and Stop hooks for Claude Code"
 echo "    CLAUDE.md                  ← Minimal activation hint for Claude Code"
 echo "    .opencode/plugins/spine.js ← Review gate enforcement and SessionStart (OpenCode)"
+echo "    .pi/extensions/spine.ts    ← Review gate enforcement and session resume (Pi)"
 echo "    opencode.json              ← OpenCode config (plugin reference + AGENTS.md natively)"
 echo ""
 echo "  Next steps:"
@@ -798,6 +808,7 @@
 echo "    3. Codex:       run 'codex'      — use \$spine-brainstorm to start a feature"
 echo "    4. Claude Code: run 'claude'     — use /spine-brainstorm to start a feature"
 echo "    5. OpenCode:    run 'opencode'   — reads AGENTS.md automatically"
+echo "    6. Pi:          run 'pi'         — extensions auto-loaded from .pi/extensions/"
 echo ""
 echo "       For the best reading experience in Neovim, install:"
```

### Acceptance gate

- [x] `grep -c "export function" hooks/spine-core.js` = 22 (≥ 20 — all pure functions extracted)
- [x] `grep "@mariozechner\|client\.session" hooks/spine-core.js` — zero hits (R1)
- [x] `grep -c "export function" hooks/opencode-spine.js` = 0 (no function defs left)
- [x] `grep "spine-core" hooks/opencode-spine.js` — 1 import block
- [x] `grep "spine-core" pi/spine.ts` — 1 import block
- [x] `cat pi/spine.ts | head -1` — `// Project Spine — Pi extension`
- [x] `bash -n install.sh` — valid shell
- [x] P1, P2, P3, P4, P5 verified by manual code review

### Agent self-review (fill after implementation)

- Hardest: Verifying Pi extension API signatures without access to type definitions
- Least confident: Pi extension runtime compatibility (can't test without Pi running)
- Deviations from plan: none — all I-steps implemented as spec'd

---

## Decisions log

## Errors

## Verification Gate
- Status: pending
- Last run: none
- Verdict: not run

## Review Gate
- Status: approved

R> APPROVED

## Resume
- Source: plan
- Phase: implementation
- Gate: approved
- Verification Gate: pending
- Current Slice: all 4 I-steps implemented — spine-core.js extracted,
  opencode-spine.js rewritten as thin adapter, pi/spine.ts created,
  install.sh updated with Pi extension steps
- Next Step: verify implementation, then run spine-verify gate
- Open Questions: none
- Files in Play: `hooks/spine-core.js` [C], `hooks/opencode-spine.js` [M],
  `pi/spine.ts` [C], `install.sh` [M]

## State
- Phase: implementation
- Verification Gate: pending
