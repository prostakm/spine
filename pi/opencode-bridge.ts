// Project Spine — OpenCode Bridge for Pi
// Generic Pi extension that loads existing OpenCode plugins from
// .opencode/plugins/*.js and bridges their hook system into Pi's
// extension API. No plugin-specific knowledge — works for any
// OpenCode plugin that exports { SpinePlugin } or default factory.
//
// Installed to .pi/extensions/opencode-bridge.ts by install.sh.

import type { ExtensionAPI, ExtensionContext } from "@mariozechner/pi-coding-agent";
import { readdirSync, existsSync } from "fs";
import { join } from "path";

// ── OpenCode plugin contract ──────────────────────────────────────────────────

interface OpenCodePlugin {
  /** Called on message events — e.g. approval mirroring from chat */
  event?(args: { event: Record<string, unknown> }): Promise<void>;
  /** Called before every tool execution — throw Error to block */
  "tool.execute.before"?(input: Record<string, unknown>, output: Record<string, unknown>): Promise<void>;
  /** Called when a session starts — e.g. context surfacing */
  "session.created"?(): Promise<void>;
}

interface OpenCodePluginFactory {
  (opts: { directory: string; client: Record<string, unknown> }):
    Promise<OpenCodePlugin> | OpenCodePlugin;
}

// ── Plugin discovery and loading ─────────────────────────────────────────────

function discoverPluginFiles(root: string): string[] {
  const dir = join(root, ".opencode", "plugins");
  if (!existsSync(dir)) return [];
  return readdirSync(dir)
    .filter(f => f.endsWith(".js"))
    .sort();
}

async function runWithoutConsoleLog(fn: () => Promise<void>): Promise<void> {
  const originalLog = console.log;
  console.log = () => {};
  try {
    await fn();
  } finally {
    console.log = originalLog;
  }
}

async function loadPlugin(
  root: string,
  fileName: string,
): Promise<{ name: string; instance: OpenCodePlugin } | null> {
  const filePath = join(root, ".opencode", "plugins", fileName);
  try {
    const mod: Record<string, unknown> = await import(filePath);
    const factory = (mod.SpinePlugin ?? mod.default) as
      | OpenCodePluginFactory
      | undefined;

    if (typeof factory !== "function") {
      console.error(`[opencode-bridge] ${fileName}: no factory export found`);
      return null;
    }

    // Minimal client stub — plugins that need client.session.message()
    // for auto-approval mirroring won't have it through the bridge.
    const client: Record<string, unknown> = {};

    const instance = await factory({ directory: root, client });
    if (!instance || typeof instance !== "object") {
      console.error(`[opencode-bridge] ${fileName}: factory returned invalid plugin`);
      return null;
    }

    return { name: fileName.replace(/\.js$/, ""), instance };
  } catch (e) {
    console.error(`[opencode-bridge] Failed to load ${fileName}:`, e);
    return null;
  }
}

// ── Pi extension entry point ─────────────────────────────────────────────────

export default function opencodeBridge(pi: ExtensionAPI): void {
  let plugins: Array<{ name: string; instance: OpenCodePlugin }> = [];
  let loaded = false;

  async function ensurePlugins(root: string): Promise<void> {
    if (loaded) return;
    loaded = true;

    const files = discoverPluginFiles(root);
    for (const file of files) {
      const p = await loadPlugin(root, file);
      if (p) plugins.push(p);
    }
  }

  // ── Gate enforcement — before every tool call ──
  //   Pi event:   { toolName, input }
  //   OpenCode:   plugin["tool.execute.before"]({ tool, args }, { args })
  //   Block via:  throw Error → return { block: true, reason }
  pi.on("tool_call", async (event: { toolName: string; input: Record<string, unknown> }) => {
    const root = process.cwd();
    await ensurePlugins(root);

    const input = { tool: event.toolName, args: event.input };
    const output = { args: event.input };

    for (const p of plugins) {
      if (!p.instance["tool.execute.before"]) continue;
      try {
        await p.instance["tool.execute.before"](input, output);
      } catch (e) {
        return {
          block: true,
          reason: e instanceof Error ? e.message : String(e),
        };
      }
    }
  });

  // ── Session start — run plugin hook quietly ──
  //   Pi event:   (event, ctx) with ctx.cwd
  //   OpenCode:   plugin["session.created"]() — stdout messages suppressed
  pi.on("session_start", async (_event: unknown, ctx: ExtensionContext) => {
    await ensurePlugins(ctx.cwd);

    for (const p of plugins) {
      const onSessionCreated = p.instance["session.created"];
      if (!onSessionCreated) continue;
      try {
        await runWithoutConsoleLog(() => onSessionCreated.call(p.instance));
      } catch (e) {
        console.error(`[opencode-bridge] ${p.name}: session.created error:`, e);
      }
    }
  });

  // ── Event handler (approval mirroring) — NOT YET IMPLEMENTED ──
  //   OpenCode's plugin.event({ event }) receives message.updated events
  //   and auto-mirrors "approved" chat into plan/spec files.
  //
  //   Pi fires before_agent_start with the user's message. Mapping this
  //   to OpenCode's message.updated shape requires understanding Pi's
  //   event payload. When that mapping is known, add:
  //
  //     pi.on("before_agent_start", async (event) => {
  //       ... map Pi message event → OpenCode message.updated ...
  //       for (const p of plugins) {
  //         await p.instance.event?.({ event: mappedEvent });
  //       }
  //     });
}
