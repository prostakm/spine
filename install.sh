#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Project Spine — Install Script
# Bootstraps the framework into the current project directory.
# Safe to run multiple times (idempotent).
# ─────────────────────────────────────────────────────────────

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[spine]${NC} $1"; }
warn()  { echo -e "${YELLOW}[spine]${NC} $1"; }
error() { echo -e "${RED}[spine]${NC} $1"; exit 1; }

# ── Resolve the directory where this script lives ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Pre-flight checks ──
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    error "Not inside a git repository. Run 'git init' first."
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"
info "Installing or updating Project Spine in: $PROJECT_ROOT"

# ── Helpers ──
copy_if_missing() {
    local src="$1" dst="$2"
    if [ -f "$dst" ]; then
        warn "Already exists: $dst — skipping"
    else
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        info "Created: $dst"
    fi
}

sync_managed_file() {
    local src="$1" dst="$2"
    [ -f "$src" ] || return 0
    mkdir -p "$(dirname "$dst")"

    if [ ! -f "$dst" ]; then
        cp "$src" "$dst"
        info "Created managed file: $dst"
        return
    fi

    if ! cmp -s "$src" "$dst"; then
        cp "$src" "$dst"
        info "Updated managed file: $dst"
    fi
}

remove_if_exists() {
    local path="$1"
    if [ -e "$path" ]; then
        rm -rf "$path"
        info "Removed stale file: $path"
    fi
}

remove_empty_dir() {
    local path="$1"
    if [ -d "$path" ] && [ -z "$(find "$path" -mindepth 1 -maxdepth 1 2>/dev/null)" ]; then
        rmdir "$path"
        info "Removed empty directory: $path"
    fi
}

replace_marked_block() {
    local file="$1" begin="$2" end="$3" source="$4"
    local tmp
    tmp="$(mktemp)"

    awk -v begin="$begin" -v end="$end" -v source="$source" '
        BEGIN {
            while ((getline line < source) > 0) {
                replacement[++count] = line
            }
            close(source)
        }
        $0 == begin {
            for (i = 1; i <= count; i++) {
                print replacement[i]
            }
            skip = 1
            next
        }
        skip && $0 == end {
            skip = 0
            next
        }
        !skip { print }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
}

upsert_marked_block() {
    local file="$1" begin="$2" end="$3" source="$4"

    if [ -f "$file" ] && grep -Fq "$begin" "$file" 2>/dev/null; then
        replace_marked_block "$file" "$begin" "$end" "$source"
        return
    fi

    [ -f "$file" ] || touch "$file"
    if [ -s "$file" ]; then
        printf '\n' >> "$file"
    fi
    cat "$source" >> "$file"
}

remove_legacy_toml_agents_block() {
    local file="$1"
    [ -f "$file" ] || return 0

    local tmp
    tmp="$(mktemp)"

    awk '
        function flush_block() {
            if (!in_agents) {
                return
            }

            if (!legacy_block) {
                printf "%s", block
            }

            block = ""
            in_agents = 0
            legacy_block = 1
        }

        /^\[agents\][[:space:]]*$/ {
            flush_block()
            in_agents = 1
            legacy_block = 1
            block = $0 ORS
            next
        }

        /^\[/ && in_agents {
            flush_block()
        }

        {
            if (in_agents) {
                block = block $0 ORS

                if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) {
                    next
                }

                if ($0 ~ /^[[:space:]]*max_threads[[:space:]]*=/ || $0 ~ /^[[:space:]]*max_depth[[:space:]]*=/) {
                    next
                }

                legacy_block = 0
                next
            }

            print
        }

        END {
            flush_block()
        }
    ' "$file" > "$tmp"

    if ! cmp -s "$file" "$tmp"; then
        mv "$tmp" "$file"
        info "Removed legacy Spine [agents] block from $file"
    else
        rm -f "$tmp"
    fi
}

remove_legacy_spine_config_block() {
    local file="$1"
    [ -f "$file" ] || return 0

    local tmp
    tmp="$(mktemp)"

    awk '
        /^# ── Project Spine settings ──$/ {
            skipping = 1
            next
        }

        /^# Project Spine runs in the main Codex session\.$/ {
            skipping = 1
            next
        }

        skipping {
            if ($0 ~ /^# Use built-in plan mode for design; keep execution handoff in `.spine\/`\.$/ ||
                $0 ~ /^# Use built-in plan mode for design; keep execution handoff in `plan\.md`\.$/ ||
                $0 ~ /^# Optional team notes live in `.spine\/config\.yaml`\.$/ ||
                $0 ~ /^# Keep workflow guardrails in skills, hooks, and AGENTS\.md\.$/ ||
                $0 ~ /^[[:space:]]*$/) {
                next
            }

            skipping = 0
        }

        { print }
    ' "$file" > "$tmp"

    if ! cmp -s "$file" "$tmp"; then
        mv "$tmp" "$file"
        info "Removed legacy Spine config guidance block from $file"
    else
        rm -f "$tmp"
    fi
}

remove_legacy_managed_instructions_block() {
    local file="$1"
    [ -f "$file" ] || return 0

    local tmp
    tmp="$(mktemp)"

    awk '
        /^# Subagent limits[[:space:]]*$/ { next }
        /^# BEGIN PROJECT SPINE MANAGED INSTRUCTIONS$/ { skip = 1; next }
        skip && /^# END PROJECT SPINE MANAGED INSTRUCTIONS$/ { skip = 0; next }
        skip { next }
        { print }
    ' "$file" > "$tmp"

    if ! cmp -s "$file" "$tmp"; then
        mv "$tmp" "$file"
        info "Removed legacy managed instructions block from $file"
    else
        rm -f "$tmp"
    fi
}

remove_legacy_yaml_section() {
    local file="$1" section="$2"
    [ -f "$file" ] || return 0

    local tmp
    tmp="$(mktemp)"

    awk -v section="$section" '
        function flush_block() {
            if (!in_block) {
                return
            }

            if (!legacy_block) {
                printf "%s", block
            }

            block = ""
            in_block = 0
            legacy_block = 1
        }

        $0 ~ "^[[:space:]]*" section ":[[:space:]]*$" {
            flush_block()
            in_block = 1
            legacy_block = 1
            block = $0 ORS
            next
        }

        $0 ~ "^[^[:space:]#]" && in_block {
            flush_block()
        }

        {
            if (in_block) {
                block = block $0 ORS

                if ($0 ~ /^[[:space:]]*$/ || $0 ~ /^[[:space:]]*#/) {
                    next
                }

                legacy_block = 1
                next
            }

            print
        }

        END {
            flush_block()
        }
    ' "$file" > "$tmp"

    if ! cmp -s "$file" "$tmp"; then
        mv "$tmp" "$file"
        info "Removed legacy Spine '${section}' section from $file"
    else
        rm -f "$tmp"
    fi
}

ensure_yaml_top_level_key() {
    local file="$1" key="$2" line="$3"
    [ -f "$file" ] || return 0

    if grep -Eq "^[[:space:]]*${key}:" "$file" 2>/dev/null; then
        return 0
    fi

    local tmp
    tmp="$(mktemp)"
    {
        printf '%s\n' "$line"
        cat "$file"
    } > "$tmp"
    mv "$tmp" "$file"
    info "Added missing Spine setting '${key}' to $file"
}

ensure_yaml_child_line() {
    local file="$1" section="$2" line="$3"
    [ -f "$file" ] || return 0

    local child_key
    child_key="$(printf '%s' "$line" | sed -E 's/^[[:space:]]*([^:#]+):.*$/\1/')"

    if awk -v section="$section" -v child_key="$child_key" '
        $0 ~ "^[[:space:]]*" section ":[[:space:]]*$" { in_section=1; next }
        in_section && $0 ~ "^[^[:space:]#]" { exit }
        in_section && $0 ~ "^[[:space:]]*" child_key ":[[:space:]]*" { found=1; exit }
        END { exit(found ? 0 : 1) }
    ' "$file"; then
        return 0
    fi

    local tmp
    tmp="$(mktemp)"

    awk -v section="$section" -v insert_line="$line" '
        $0 ~ "^[[:space:]]*" section ":[[:space:]]*$" {
            print
            print insert_line
            inserted = 1
            next
        }
        { print }
        END {
            if (!inserted) {
                print section ":"
                print insert_line
            }
        }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
    info "Added missing Spine setting '${child_key}' under '${section}' in $file"
}

install_claude_skills() {
    local src_dir="$1" dst_dir="$2"
    mkdir -p "$dst_dir/spine-brainstorm" "$dst_dir/spine-pwf" "$dst_dir/spine-spec"
    sync_managed_file "$src_dir/spine-brainstorm/SKILL.md" "$dst_dir/spine-brainstorm/SKILL.md"
    sync_managed_file "$src_dir/spine-pwf/SKILL.md"        "$dst_dir/spine-pwf/SKILL.md"
    sync_managed_file "$src_dir/spine-spec/SKILL.md"       "$dst_dir/spine-spec/SKILL.md"
}

merge_claude_settings_hooks() {
    local settings_file="$1"
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not found — skipping $settings_file"
        return 1
    fi
    mkdir -p "$(dirname "$settings_file")"
    python3 - "$settings_file" <<'PY'
import json, os, sys

settings_path = sys.argv[1]

try:
    with open(settings_path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

if not isinstance(data.get("hooks"), dict):
    data["hooks"] = {}

hooks = data["hooks"]

SENTINEL = ".codex/hooks/"

def is_spine_hook(entry):
    for h in entry.get("hooks", []):
        if isinstance(h.get("command"), str) and SENTINEL in h["command"]:
            return True
    return False

for event in ("PreToolUse", "PostToolUse", "Stop"):
    if isinstance(hooks.get(event), list):
        hooks[event] = [e for e in hooks[event] if not is_spine_hook(e)]
        if not hooks[event]:
            del hooks[event]

root_cmd = "bash -lc 'ROOT=$(git rev-parse --show-toplevel 2>/dev/null); [ -n \"$ROOT\" ] && \"$ROOT/.codex/hooks/{hook}\"'"

spine_entries = {
    "Stop": {"matcher": ".*", "hooks": [{"type": "command", "command": root_cmd.format(hook="stop.sh")}]},
}

for event, entry in spine_entries.items():
    hooks.setdefault(event, [])
    hooks[event].append(entry)

data["hooks"] = hooks

tmp = settings_path + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, settings_path)
PY
}

upsert_opencode_json() {
    local dst="$1"
    local plugin_path=".opencode/plugins/spine.js"
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not found — skipping $dst"
        return 1
    fi
    local existed=0 backup=""
    [ -f "$dst" ] && existed=1
    if [ $existed -eq 1 ]; then
        backup="$(mktemp)"
        cp "$dst" "$backup"
    fi
    python3 - "$dst" "$plugin_path" <<'PY'
import json, os, sys

dst, plugin_path = sys.argv[1], sys.argv[2]

try:
    with open(dst) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

plugins = data.get("plugin", [])
if (isinstance(plugins, list) and plugin_path in plugins and "$schema" in data):
    sys.exit(0)  # already configured — nothing to write

data.setdefault("$schema", "https://opencode.ai/config.json")
if not isinstance(plugins, list):
    plugins = []
if plugin_path not in plugins:
    plugins.append(plugin_path)
data["plugin"] = plugins

tmp = dst + ".tmp"
with open(tmp, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
os.replace(tmp, dst)
PY
    if [ $existed -eq 0 ]; then
        info "Created: $dst"
    elif [ -n "$backup" ] && ! cmp -s "$backup" "$dst" 2>/dev/null; then
        info "Updated: $dst"
    fi
    [ -n "$backup" ] && rm -f "$backup"
}

# ── Step 1: Create .spine/ directory structure ──

# Project-level files
copy_if_missing "$SCRIPT_DIR/templates/.spine/project.md"      ".spine/project.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/conventions.md"   ".spine/conventions.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/progress.md"      ".spine/progress.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/config.yaml"      ".spine/config.yaml"
remove_legacy_yaml_section ".spine/config.yaml" "agents"
ensure_yaml_top_level_key ".spine/config.yaml" "autonomy" "autonomy: med  # low | med | high"
ensure_yaml_child_line ".spine/config.yaml" "models" "  brainstorm: { model: gpt-5.4, effort: high }"

# Active feature tracker
if [ ! -f ".spine/active-feature" ]; then
    touch ".spine/active-feature"
    info "Created: .spine/active-feature"
fi

# Feature templates
mkdir -p ".spine/features/_template"
sync_managed_file "$SCRIPT_DIR/templates/.spine/features/_template/plan.md"     ".spine/features/_template/plan.md"
sync_managed_file "$SCRIPT_DIR/templates/.spine/features/_template/findings.md" ".spine/features/_template/findings.md"
sync_managed_file "$SCRIPT_DIR/templates/.spine/features/_template/log.md"      ".spine/features/_template/log.md"
sync_managed_file "$SCRIPT_DIR/templates/.spine/features/_template/spec.md"     ".spine/features/_template/spec.md"

# Planning utilities
mkdir -p ".spine/scripts"
sync_managed_file "$SCRIPT_DIR/scripts/validate-plan.sh" ".spine/scripts/validate-plan.sh"
chmod +x ".spine/scripts/validate-plan.sh" 2>/dev/null || true

# ── Step 2: Copy Codex config.toml (merge if exists) ──
SPINE_CONFIG_BLOCK_BEGIN="# BEGIN PROJECT SPINE CONFIG"
SPINE_CONFIG_BLOCK_END="# END PROJECT SPINE CONFIG"
SPINE_CONFIG_BLOCK_FILE="$(mktemp)"
cat > "$SPINE_CONFIG_BLOCK_FILE" <<'TOML'
# BEGIN PROJECT SPINE CONFIG
# Project Spine runs in the main Codex session.
# Use built-in plan mode for design; keep execution handoff in `plan.md`.
# Optional team notes live in `.spine/config.yaml`.
# Keep workflow guardrails in skills, hooks, and AGENTS.md.
# END PROJECT SPINE CONFIG
TOML

if [ -f ".codex/config.toml" ]; then
    remove_legacy_toml_agents_block ".codex/config.toml"
    remove_legacy_spine_config_block ".codex/config.toml"
    remove_legacy_managed_instructions_block ".codex/config.toml"
    upsert_marked_block ".codex/config.toml" "$SPINE_CONFIG_BLOCK_BEGIN" "$SPINE_CONFIG_BLOCK_END" "$SPINE_CONFIG_BLOCK_FILE"
    info "Updated managed Spine block in .codex/config.toml"
else
    copy_if_missing "$SCRIPT_DIR/templates/.codex/config.toml" ".codex/config.toml"
fi
rm -f "$SPINE_CONFIG_BLOCK_FILE"

# ── Step 3: Copy skills ──
mkdir -p ".agents/skills/spine-brainstorm"
mkdir -p ".agents/skills/spine-pwf"
mkdir -p ".agents/skills/spine-spec"
sync_managed_file "$SCRIPT_DIR/.agents/skills/spine-brainstorm/SKILL.md" ".agents/skills/spine-brainstorm/SKILL.md"
sync_managed_file "$SCRIPT_DIR/.agents/skills/spine-pwf/SKILL.md"  ".agents/skills/spine-pwf/SKILL.md"
sync_managed_file "$SCRIPT_DIR/.agents/skills/spine-spec/SKILL.md" ".agents/skills/spine-spec/SKILL.md"

# ── Step 4: Copy hook scripts ──
mkdir -p ".codex/hooks"
for hook in session-start.sh stop.sh; do
    if [ -f "$SCRIPT_DIR/hooks/$hook" ]; then
        sync_managed_file "$SCRIPT_DIR/hooks/$hook" ".codex/hooks/$hook"
        chmod +x ".codex/hooks/$hook"
    fi
done

sync_managed_file "$SCRIPT_DIR/hooks/hooks.json" ".codex/hooks.json"
remove_if_exists ".codex/hooks/hooks.json"

# ── Step 5: Handle AGENTS.md ──
AGENTS_TEMPLATE="$SCRIPT_DIR/templates/AGENTS.md"
SPINE_BEGIN="<!-- BEGIN PROJECT SPINE -->"
SPINE_END="<!-- END PROJECT SPINE -->"

if [ -f "AGENTS.md" ]; then
    # Check if spine section already exists
    if grep -Fq "$SPINE_BEGIN" "AGENTS.md" 2>/dev/null; then
        info "Updating existing Project Spine section in AGENTS.md..."
        replace_marked_block "AGENTS.md" "# ${SPINE_BEGIN}" "# ${SPINE_END}" "$AGENTS_TEMPLATE"
        info "Updated spine workflow in AGENTS.md"
    else
        info "Appending Project Spine section to existing AGENTS.md..."
        echo "" >> "AGENTS.md"
        echo "---" >> "AGENTS.md"
        echo "" >> "AGENTS.md"
        cat "$AGENTS_TEMPLATE" >> "AGENTS.md"
        info "Appended spine workflow to AGENTS.md"
    fi
else
    cp "$AGENTS_TEMPLATE" "AGENTS.md"
    info "Created: AGENTS.md"
fi

# ── Step 6: Remove stale files from older Spine installations ──
for f in .codex/agents/spine-*.toml; do
    [ -f "$f" ] && rm -f "$f" && info "Removed: $f"
done
remove_empty_dir ".codex/agents"
remove_if_exists ".codex/hooks.json.bak"
remove_if_exists ".codex/hooks/hooks.json.bak"

remove_if_exists ".agents/skills/spine-explorer"
remove_if_exists ".agents/skills/spine-worker"
remove_if_exists ".agents/skills/spine-reviewer"
remove_if_exists ".agents/skills/spine-review"
remove_if_exists ".agents/skills/spine-execution"
remove_if_exists ".codex/hooks/pre-tool-use"
remove_if_exists ".codex/hooks/post-tool-use"
remove_if_exists ".codex/hooks/stop"
remove_if_exists ".codex/hooks/session-start"
remove_if_exists ".codex/hooks/pre-tool-use.old"
remove_if_exists ".codex/hooks/post-tool-use.old"
remove_if_exists ".codex/hooks/pre-tool-use.sh"
remove_if_exists ".codex/hooks/post-tool-use.sh"
remove_if_exists ".codex/hooks/stop.old"
remove_if_exists ".codex/hooks/session-start.old"
remove_if_exists ".codex/hooks/pre_tool_use.sh"
remove_if_exists ".codex/hooks/post_tool_use.sh"
remove_if_exists ".codex/hooks/session_start.sh"
remove_if_exists ".codex/hooks/hooks.json.old"
remove_empty_dir ".codex/hooks"

# ── Step 7: Update .gitignore ──
GITIGNORE_ENTRIES=(
    ".spine/active-feature"
)
if [ -f ".gitignore" ]; then
    for entry in "${GITIGNORE_ENTRIES[@]}"; do
        if ! grep -qF "$entry" ".gitignore" 2>/dev/null; then
            echo "$entry" >> ".gitignore"
            info "Added to .gitignore: $entry"
        fi
    done
else
    printf '%s\n' "${GITIGNORE_ENTRIES[@]}" > ".gitignore"
    info "Created .gitignore with spine entries"
fi

# ── Step 8: Claude Code skills ──
install_claude_skills "$SCRIPT_DIR/.agents/skills" ".claude/skills"

# ── Step 9: Claude Code hooks ──
if merge_claude_settings_hooks ".claude/settings.json"; then
    info "Spine hooks merged into .claude/settings.json"
else
    warn "Skipped .claude/settings.json — python3 unavailable or parse error"
fi

# ── Step 9b: Handle CLAUDE.md ──
CLAUDE_TEMPLATE="$SCRIPT_DIR/templates/CLAUDE.md"
CLAUDE_SPINE_BEGIN="<!-- BEGIN PROJECT SPINE -->"
CLAUDE_SPINE_END="<!-- END PROJECT SPINE -->"

if [ -f "CLAUDE.md" ]; then
    if grep -Fq "$CLAUDE_SPINE_BEGIN" "CLAUDE.md" 2>/dev/null; then
        info "Updating existing Project Spine section in CLAUDE.md..."
        replace_marked_block "CLAUDE.md" "# ${CLAUDE_SPINE_BEGIN}" "# ${CLAUDE_SPINE_END}" "$CLAUDE_TEMPLATE"
        info "Updated spine workflow in CLAUDE.md"
    else
        info "Appending Project Spine section to existing CLAUDE.md..."
        echo "" >> "CLAUDE.md"
        echo "---" >> "CLAUDE.md"
        echo "" >> "CLAUDE.md"
        cat "$CLAUDE_TEMPLATE" >> "CLAUDE.md"
        info "Appended spine workflow to CLAUDE.md"
    fi
else
    cp "$CLAUDE_TEMPLATE" "CLAUDE.md"
    info "Created: CLAUDE.md"
fi

# ── Step 10: OpenCode plugin and config ──
mkdir -p ".opencode/plugins"
sync_managed_file "$SCRIPT_DIR/hooks/opencode-spine.js" ".opencode/plugins/spine.js"
upsert_opencode_json "opencode.json"

# ── Summary ──
echo ""
echo -e "${GREEN}╭─────────────────────────────────────────────╮${NC}"
echo -e "${GREEN}│  Project Spine installed successfully        │${NC}"
echo -e "${GREEN}╰─────────────────────────────────────────────╯${NC}"
echo ""
echo "  Created:"
echo "    .spine/project.md          ← Edit: add your project vision + constraints"
echo "    .spine/conventions.md      ← Edit: add your coding conventions"
echo "    .spine/progress.md         ← Auto-updated as features complete"
echo "    .spine/config.yaml         ← Set autonomy: low|med|high"
echo "    .spine/features/_template/ ← Spec, plan, and optional findings/log templates"
echo "    .codex/config.toml         ← Main-session Codex defaults"
echo "    .codex/hooks.json          ← Codex hook configuration"
echo "    .codex/hooks/              ← SessionStart and Stop hooks"
echo "    .agents/skills/            ← spine-brainstorm, spine-pwf, and spine-spec (Codex)"
echo "    AGENTS.md                  ← Workflow instructions for Codex and OpenCode"
echo "    .claude/skills/            ← spine-brainstorm, spine-pwf, and spine-spec (Claude Code)"
echo "    .claude/settings.json      ← Stop hook for Claude Code"
echo "    CLAUDE.md                  ← Workflow instructions for Claude Code"
echo "    .opencode/plugins/spine.js ← Review gate enforcement and SessionStart (OpenCode)"
echo "    opencode.json              ← OpenCode config (plugin reference + AGENTS.md natively)"
echo ""
echo "  Next steps:"
echo "    1. Edit .spine/project.md with your project details"
echo "    2. Edit .spine/conventions.md with your coding conventions"
echo "    3. Codex:       run 'codex'      — use \$spine-brainstorm to start a feature"
echo "    4. Claude Code: run 'claude'     — use /spine-brainstorm to start a feature"
echo "    5. OpenCode:    run 'opencode'   — reads AGENTS.md automatically"
echo ""
