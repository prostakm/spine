// Project Spine — core gate-enforcement logic
// Platform-agnostic pure functions shared by OpenCode and Pi adapters.

import { readFileSync, existsSync, writeFileSync } from "fs"
import { join } from "path"

export function readSlug(root) {
  const f = join(root, ".spine", "active-feature")
  if (!existsSync(f)) return null
  return readFileSync(f, "utf8").trim() || null
}

export function planPath(root, slug) {
  return join(root, ".spine", "features", slug, "plan.md")
}

export function specPath(root, slug) {
  return join(root, ".spine", "features", slug, "spec.md")
}

export function readPlan(p) {
  return existsSync(p) ? readFileSync(p, "utf8") : null
}

export function normalizePath(filePath, root) {
  if (!filePath) return null
  return filePath.startsWith("/") ? filePath : join(root, filePath)
}

export function fieldValue(content, heading, field) {
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

export function extractSection(content, heading) {
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

export function planIsApproved(content) {
  if (/^R>\s*APPROVED(\s|$)/m.test(content)) return true
  if (/^> \[R\]:\s*APPROVED(\s|$)/m.test(content)) return true
  return fieldValue(content, "Review Gate", "Status") === "approved"
}

export function pickResumeFile(root, slug) {
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

export function setFieldValue(content, heading, field, value) {
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

export function setSectionStatus(content, heading, value) {
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

export function markPlanApproved(content) {
  let next = setFieldValue(content, "Review Gate", "Status", "approved")
  const hasApprovalMarker =
    /^R>\s*APPROVED(\s|$)/m.test(next) || /^> \[R\]:\s*APPROVED(\s|$)/m.test(next)
  if (!hasApprovalMarker && next.includes("\n## Review Gate")) {
    next = next.replace("\n## Review Gate", "\nR> APPROVED\n\n## Review Gate")
  }
  return next
}

export function markSpecApproved(content) {
  let next = content
  next = setFieldValue(next, "Status", "Brainstorm", "complete")
  next = setFieldValue(next, "Status", "Design", "approved")
  next = setFieldValue(next, "Status", "Spec", "approved")
  return setSectionStatus(next, "Proposed Design", "approved")
}

export function writeIfChanged(filePath, next) {
  if (!next || !existsSync(filePath)) return
  const prev = readFileSync(filePath, "utf8")
  if (prev !== next) writeFileSync(filePath, next)
}

export function collectNestedPaths(value, out = new Set()) {
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

export function extractPatchTargets(patchText) {
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

export function collectToolTargets(tool, args) {
  if (tool === "apply_patch") {
    const patchTargets = extractPatchTargets(args?.patchText ?? args?.patch_text ?? "")
    if (patchTargets.length > 0) return patchTargets
  }
  return [...collectNestedPaths(args)]
}

export function allowedPendingPaths(root, slug) {
  return new Set([planPath(root, slug), specPath(root, slug)])
}

export function allTargetsAllowedWhilePending(tool, args, root, slug) {
  const targets = collectToolTargets(tool, args)
  if (targets.length === 0) return false
  const allowed = allowedPendingPaths(root, slug)
  return targets.every(target => allowed.has(normalizePath(target, root)))
}

export function approvalTarget(text) {
  const normalized = text.trim().toLowerCase()
  if (!normalized) return null
  if (/^(approved|i approve|approve)\.?$/.test(normalized)) return "generic"
  if (/^(plan approved|i approve the plan|i approve plan)\.?$/.test(normalized)) return "plan"
  if (/^(spec approved|i approve the spec|i approve spec)\.?$/.test(normalized)) return "spec"
  return null
}

export function extractMessageText(parts) {
  return parts
    .filter(part => part?.type === "text" && !part.synthetic && !part.ignored)
    .map(part => part.text)
    .join("\n")
    .trim()
}

const SHELL_OPS = [">", "<", "|", ";", "$(", "`", "&&", "||"]

const READ_ONLY_PREFIXES = [
  "cat ", "sed ", "rg ", "grep ", "find ", "ls ", "head ", "tail ",
  "wc ", "nl ", "awk ", "cut ", "sort ", "uniq ", "tr ", "stat ",
  "git status", "git diff", "git show", "git rev-parse",
  "git branch", "git log", "git blame",
]

const READ_ONLY_SCRIPTS = [
  ".spine/scripts/validate-plan.sh",
  "scripts/validate-plan.sh",
  ".spine/scripts/validate-spine-doc.sh",
  "scripts/validate-spine-doc.sh",
  ".spine/scripts/extract-verification-context.sh",
  "scripts/extract-verification-context.sh",
]

function stripWrappingQuotes(token) {
  if (!token || token.length < 2) return token
  const first = token[0]
  const last = token[token.length - 1]
  if ((first === '"' || first === "'") && first === last) {
    return token.slice(1, -1)
  }
  return token
}

function normalizeCommandWord(token) {
  const unquoted = stripWrappingQuotes(token.trim())
  return unquoted.replace(/^\.\//, "")
}

function tokenizeShellCommand(cmd) {
  return cmd.match(/"[^"]*"|'[^']*'|\S+/g) ?? []
}

function matchesReadOnlyScript(words) {
  if (words.length === 0) return false

  const [first, second] = words
  const firstWord = normalizeCommandWord(first)
  const secondWord = normalizeCommandWord(second ?? "")

  if (READ_ONLY_SCRIPTS.includes(firstWord)) return true
  if (["bash", "sh"].includes(firstWord) && READ_ONLY_SCRIPTS.includes(secondWord)) {
    return true
  }

  return false
}

export function bashAllowed(cmd) {
  if (!cmd) return false
  if (SHELL_OPS.some(op => cmd.includes(op))) return false

  const words = tokenizeShellCommand(cmd)
  if (matchesReadOnlyScript(words)) return true

  const normalized = words.map(normalizeCommandWord).join(" ")
  return READ_ONLY_PREFIXES.some(
    prefix => normalized === prefix.trim() || normalized.startsWith(prefix)
  )
}
