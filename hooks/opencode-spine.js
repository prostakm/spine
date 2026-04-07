// Project Spine — OpenCode plugin
// Enforces the plan review gate before edits and keeps plan.md authoritative after writes.
// Installed to .opencode/plugins/spine.js in your project by install.sh.

import { readFileSync, existsSync } from "fs"
import { join } from "path"

// ── Helpers ───────────────────────────────────────────────────────────────────

function readSlug(root) {
  const f = join(root, ".spine", "active-feature")
  if (!existsSync(f)) return null
  return readFileSync(f, "utf8").trim() || null
}

function planPath(root, slug) {
  return join(root, ".spine", "features", slug, "plan.md")
}

function readPlan(p) {
  return existsSync(p) ? readFileSync(p, "utf8") : null
}

function fieldValue(content, heading, field) {
  const lines = content.split("\n")
  const head = `## ${heading}`
  const pat = new RegExp(`^\\s*-\\s*${field}:\\s*(.*)$`)
  let inSection = false
  let waiting = false
  for (const line of lines) {
    if (line === head) { inSection = true; continue }
    if (inSection && /^## /.test(line)) break
    if (!inSection) continue
    const m = line.match(pat)
    if (m) {
      if (m[1].trim()) return m[1].trim()
      waiting = true
      continue
    }
    if (waiting) {
      if (/^\s+[^\-`0-9]/.test(line)) return line.trim()
      if (!/^\s*$/.test(line)) break
    }
  }
  return null
}

function extractSection(content, heading) {
  const lines = content.split("\n")
  const head = `## ${heading}`
  let inSection = false
  const out = []
  for (const line of lines) {
    if (line === head) { inSection = true; continue }
    if (inSection && /^## /.test(line)) break
    if (inSection) out.push(line)
  }
  return out.join("\n").trim()
}

function planIsApproved(content) {
  // Shorthand: > [R]: APPROVED
  if (/^> \[R\]:\s*APPROVED(\s|$)/m.test(content)) return true
  return fieldValue(content, "Review Gate", "Status") === "approved"
}

function isSpinePath(filePath, root) {
  if (!filePath) return false
  const spinePath = join(root, ".spine")
  const abs = filePath.startsWith("/") ? filePath : join(root, filePath)
  return abs === spinePath || abs.startsWith(spinePath + "/")
}

// Shell operators that signal a command is not read-only
const SHELL_OPS = [">", "<", "|", ";", "$(", "`", "&&", "||"]

const READ_ONLY_PREFIXES = [
  "cat ", "sed ", "rg ", "grep ", "find ", "ls ", "head ", "tail ",
  "wc ", "nl ", "awk ", "cut ", "sort ", "uniq ", "tr ", "stat ",
  "git status", "git diff", "git show", "git rev-parse",
  "git branch", "git log", "git blame",
  ".spine/scripts/validate-plan.sh",
  "bash .spine/scripts/validate-plan.sh",
  "sh .spine/scripts/validate-plan.sh",
]

function bashAllowed(cmd) {
  if (!cmd) return false
  if (SHELL_OPS.some(op => cmd.includes(op))) return false
  const c = cmd.trim()
  return READ_ONLY_PREFIXES.some(p => c === p.trim() || c.startsWith(p))
}

// ── Plugin ────────────────────────────────────────────────────────────────────

export const SpinePlugin = async ({ directory }) => {
  const root = directory

  return {
    // Enforce the review gate before any write or bash tool runs
    "tool.execute.before": async (input, output) => {
      const tool = input?.tool ?? ""
      // OpenCode may place args on input or output depending on version
      const args = output?.args ?? input?.args ?? {}
      const filePath = args?.filePath ?? args?.path ?? args?.file_path ?? ""
      const cmd = args?.command ?? args?.cmd ?? ""

      const slug = readSlug(root)
      if (!slug) return

      const plan = planPath(root, slug)
      const content = readPlan(plan)
      if (!content) return
      if (planIsApproved(content)) return

      // Plan pending — block writes on non-.spine files
      if (["write", "edit", "apply_patch", "multipatch"].includes(tool)) {
        if (!isSpinePath(filePath, root)) {
          throw new Error(
            `[spine] Plan review gate is pending for '${slug}'. ` +
            `Record approval in ${plan} before editing non-.spine files.`
          )
        }
      }

      // Plan pending — block non-read-only bash
      if (tool === "bash" && !bashAllowed(cmd)) {
        throw new Error(
          `[spine] Plan review gate is pending for '${slug}'. ` +
          `Only read-only commands are allowed until approval is recorded in ${plan}.`
        )
      }
    },

    // After writes — remind to keep plan.md in sync
    "tool.execute.after": async (input) => {
      const tool = input?.tool ?? ""
      if (!["write", "edit", "apply_patch", "multipatch"].includes(tool)) return

      const slug = readSlug(root)
      if (!slug) return

      const plan = planPath(root, slug)
      const content = readPlan(plan)
      if (!content) return

      if (planIsApproved(content)) {
        console.log(
          `[spine] ${slug}: update ${plan} — Current Slice, Execution Slices, and State.`
        )
      }
    },

    // On session start — surface active feature context
    "session.created": async () => {
      const slug = readSlug(root)
      if (!slug) return

      const plan = planPath(root, slug)
      const content = readPlan(plan)
      if (!content) return

      const approved = planIsApproved(content)
      const phase = fieldValue(content, "State", "Phase") ?? "unknown"
      const gate = approved ? "approved" : "pending"
      const slice = extractSection(content, "Current Slice")

      const msg = slice
        ? `[spine] ${slug} | ${phase} | gate: ${gate}\n${slice}`
        : `[spine] ${slug} | ${phase} | gate: ${gate} | plan: ${plan}`

      console.log(msg)
    },
  }
}
