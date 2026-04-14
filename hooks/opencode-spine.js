// Project Spine — OpenCode plugin
// Enforces the plan review gate before edits and surfaces context on session start.
// Explicit chat approval is mirrored into the active plan/spec file.
// Installed to .opencode/plugins/spine.js in your project by install.sh.

import { readFileSync, existsSync, writeFileSync } from "fs"
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

function specPath(root, slug) {
  return join(root, ".spine", "features", slug, "spec.md")
}

function readPlan(p) {
  return existsSync(p) ? readFileSync(p, "utf8") : null
}

function pickResumeFile(root, slug) {
  const plan = planPath(root, slug)
  const spec = specPath(root, slug)
  const planContent = readPlan(plan)
  const specContent = readPlan(spec)

  if (!planContent && !specContent) return null

  if (planContent) {
    const preferred = fieldValue(planContent, "Resume", "Source")
    if (preferred === "spec" && specContent) {
      return { source: "spec", path: spec, content: specContent }
    }
    return { source: "plan", path: plan, content: planContent }
  }

  return { source: "spec", path: spec, content: specContent }
}

function normalizePath(filePath, root) {
  if (!filePath) return null
  return filePath.startsWith("/") ? filePath : join(root, filePath)
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

function setFieldValue(content, heading, field, value) {
  const lines = content.split("\n")
  const head = `## ${heading}`
  const pat = new RegExp(`^\\s*-\\s*${field}:\\s*(.*)$`)
  let inSection = false
  let insertAt = lines.length
  for (let i = 0; i < lines.length; i++) {
    if (lines[i] === head) {
      inSection = true
      insertAt = i + 1
      continue
    }
    if (inSection && /^## /.test(lines[i])) {
      let at = i
      while (at > 0 && lines[at - 1] === "") at--
      lines.splice(at, 0, `- ${field}: ${value}`)
      return lines.join("\n")
    }
    if (inSection && pat.test(lines[i])) {
      lines[i] = `- ${field}: ${value}`
      return lines.join("\n")
    }
    if (inSection) insertAt = i + 1
  }
  if (inSection) {
    let at = insertAt
    while (at > 0 && lines[at - 1] === "") at--
    lines.splice(at, 0, `- ${field}: ${value}`)
    return lines.join("\n")
  }
  return content
}

function setSectionStatus(content, heading, value) {
  const lines = content.split("\n")
  const head = `## ${heading}`
  let inSection = false
  for (let i = 0; i < lines.length; i++) {
    if (lines[i] === head) {
      inSection = true
      continue
    }
    if (inSection && /^## /.test(lines[i])) {
      lines.splice(i, 0, `Status: ${value}`)
      return lines.join("\n")
    }
    if (inSection && /^Status:\s*/.test(lines[i])) {
      lines[i] = `Status: ${value}`
      return lines.join("\n")
    }
  }
  return inSection ? [...lines, `Status: ${value}`].join("\n") : content
}

function markPlanApproved(content) {
  let next = setFieldValue(content, "Review Gate", "Status", "approved")
  if (!/^> \[R\]:\s*APPROVED(\s|$)/m.test(next) && next.includes("\n## Review Gate")) {
    next = next.replace("\n## Review Gate", "\n> [R]: APPROVED\n\n## Review Gate")
  }
  return next
}

function markSpecApproved(content) {
  let next = content
  next = setFieldValue(next, "Status", "Brainstorm", "complete")
  next = setFieldValue(next, "Status", "Design", "approved")
  next = setFieldValue(next, "Status", "Spec", "approved")
  return setSectionStatus(next, "Proposed Design", "approved")
}

function writeIfChanged(filePath, next) {
  if (!next || !existsSync(filePath)) return
  const prev = readFileSync(filePath, "utf8")
  if (prev !== next) writeFileSync(filePath, next)
}

function collectNestedPaths(value, out = new Set()) {
  if (!value || typeof value !== "object") return out
  if (Array.isArray(value)) {
    for (const item of value) collectNestedPaths(item, out)
    return out
  }
  for (const [key, nested] of Object.entries(value)) {
    if (["filePath", "file_path", "path"].includes(key) && typeof nested === "string") {
      out.add(nested)
      continue
    }
    collectNestedPaths(nested, out)
  }
  return out
}

function extractPatchTargets(patchText) {
  if (!patchText) return []
  const out = []
  const patterns = [
    /^\*\*\* (?:Add|Update|Delete) File: (.+)$/gm,
    /^\*\*\* Move to: (.+)$/gm,
  ]
  for (const pattern of patterns) {
    for (const match of patchText.matchAll(pattern)) {
      out.push(match[1].trim())
    }
  }
  return out
}

function collectToolTargets(tool, args) {
  if (tool === "apply_patch") {
    const patchTargets = extractPatchTargets(args?.patchText ?? args?.patch_text ?? "")
    if (patchTargets.length > 0) return patchTargets
  }
  return [...collectNestedPaths(args)]
}

function allowedPendingPaths(root, slug) {
  return new Set([planPath(root, slug), specPath(root, slug)])
}

function allTargetsAllowedWhilePending(tool, args, root, slug) {
  const targets = collectToolTargets(tool, args)
  if (targets.length === 0) return false
  const allowed = allowedPendingPaths(root, slug)
  return targets.every(target => allowed.has(normalizePath(target, root)))
}

function approvalTarget(text) {
  const normalized = text.trim().toLowerCase()
  if (!normalized) return null
  if (/^(approved|i approve|approve)\.?$/.test(normalized)) return "generic"
  if (/^(plan approved|i approve the plan|i approve plan)\.?$/.test(normalized)) return "plan"
  if (/^(spec approved|i approve the spec|i approve spec)\.?$/.test(normalized)) return "spec"
  return null
}

function extractMessageText(parts) {
  return parts
    .filter(part => part?.type === "text" && !part.synthetic && !part.ignored)
    .map(part => part.text)
    .join("\n")
    .trim()
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

export const SpinePlugin = async ({ directory, client }) => {
  const root = directory

  return {
    event: async ({ event }) => {
      if (event.type !== "message.updated") return

      const info = event.properties?.info
      if (!info || info.role !== "user") return

      const slug = readSlug(root)
      if (!slug) return

      const message = await client.session.message({
        path: { id: info.sessionID, messageID: info.id },
        query: { directory: root },
      }).catch(() => null)
      const text = extractMessageText(message?.data?.parts ?? [])
      const target = approvalTarget(text)
      if (!target) return

      const plan = planPath(root, slug)
      const spec = specPath(root, slug)

      if (target !== "spec") {
        const content = readPlan(plan)
        if (content && !planIsApproved(content)) {
          writeIfChanged(plan, markPlanApproved(content))
          return
        }
      }

      if (target !== "plan") {
        const content = readPlan(spec)
        if (content) writeIfChanged(spec, markSpecApproved(content))
      }
    },

    // Enforce the review gate before any write or bash tool runs
    "tool.execute.before": async (input, output) => {
      const tool = input?.tool ?? ""
      // OpenCode may place args on input or output depending on version
      const args = output?.args ?? input?.args ?? {}
      const cmd = args?.command ?? args?.cmd ?? ""

      const slug = readSlug(root)
      if (!slug) return

      const plan = planPath(root, slug)
      const content = readPlan(plan)
      if (!content) return
      if (planIsApproved(content)) return

      // Plan pending — block writes on non-.spine files
      if (["write", "edit", "apply_patch", "multiedit", "multipatch"].includes(tool)) {
        if (!allTargetsAllowedWhilePending(tool, args, root, slug)) {
          throw new Error(
            `[spine] Plan review gate is pending for '${slug}'. ` +
            `Only explicit edits to ${plan} or ${specPath(root, slug)} are allowed until approval is recorded. ` +
            `Record approval in ${plan} or say 'approved' in chat.`
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

    // On session start — surface active feature context
    "session.created": async () => {
      const slug = readSlug(root)
      if (!slug) return

      const resume = pickResumeFile(root, slug)
      if (!resume) return

      const phase = fieldValue(resume.content, "Resume", "Phase")
        ?? (resume.source === "plan" ? fieldValue(resume.content, "State", "Phase") : null)
        ?? (resume.source === "spec" ? "spec" : null)
        ?? "unknown"
      const gate = fieldValue(resume.content, "Resume", "Gate")
        ?? (resume.source === "plan"
          ? (planIsApproved(resume.content) ? "approved" : fieldValue(resume.content, "Review Gate", "Status"))
          : "pending")
        ?? "pending"
      const slice = fieldValue(resume.content, "Resume", "Current Slice")
        ?? extractSection(resume.content, "Current Slice")
        ?? (resume.source === "spec" ? "review the active spec and decide if it is ready for planning" : null)
      const next = fieldValue(resume.content, "Resume", "Next Step")
        ?? (resume.source === "spec" ? `approve the spec or run $spine-pwf ${slug} when ready to plan` : null)

      const parts = [`[spine] ${slug}`, `source: ${resume.source}`, `phase: ${phase}`, `gate: ${gate}`]
      if (next) parts.push(`next: ${next}`)

      const msg = slice
        ? `${parts.join(" | ")}\n${slice}`
        : `${parts.join(" | ")} | file: ${resume.path}`

      console.log(msg)
    },
  }
}
