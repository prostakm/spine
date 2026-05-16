// Project Spine — OpenCode plugin
// Enforces the plan review gate before edits and surfaces context on session start.
// Explicit chat approval is mirrored into the active plan/spec file.
// Installed to .opencode/plugins/spine.js in your project by install.sh.

import {
  readSlug,
  planPath,
  specPath,
  readPlan,
  pickResumeFile,
  planIsApproved,
  markPlanApproved,
  markSpecApproved,
  writeIfChanged,
  allTargetsAllowedWhilePending,
  approvalTarget,
  extractMessageText,
  bashAllowed,
  fieldValue,
  extractSection,
} from "./spine-core.js"

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
      const verification = resume.source === "plan"
        ? fieldValue(resume.content, "Resume", "Verification Gate")
          ?? fieldValue(resume.content, "Verification Gate", "Status")
        : null

      const parts = [`[spine] ${slug}`, `source: ${resume.source}`, `phase: ${phase}`, `gate: ${gate}`]
      if (verification) parts.push(`verification: ${verification}`)
      if (next) parts.push(`next: ${next}`)

      const msg = slice
        ? `${parts.join(" | ")}\n${slice}`
        : `${parts.join(" | ")} | file: ${resume.path}`

      console.log(msg)
    },
  }
}
