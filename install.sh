#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Project Spine — Install Script
# Bootstraps the framework into the current project directory.
# Safe to run multiple times (idempotent).
# ─────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[spine]${NC} $1"; }
warn()  { echo -e "${YELLOW}[spine]${NC} $1"; }
error() { echo -e "${RED}[spine]${NC} $1"; exit 1; }

SPINE_CONFIG_BEGIN="# BEGIN PROJECT SPINE MANAGED INSTRUCTIONS"
SPINE_CONFIG_END="# END PROJECT SPINE MANAGED INSTRUCTIONS"
read -r -d '' SPINE_DEVELOPER_INSTRUCTIONS <<'EOF' || true
developer_instructions = """
Project Spine execution policy:
- Main thread owns requirements, approvals, integration decisions, and final user communication.
- Skills do not change models; only explicit subagent delegation changes models.
- Use `spine_planner` to draft or revise `plan.md` when spine planning is active.
- For approved non-trivial implementation work, explicitly spawn `spine_worker_simple`.
- Escalate to `spine_worker_complex` only for cross-cutting, refactor-heavy, migration-like, or failure-prone phases.
- Use `spine_explorer` only for read-heavy prep when extra research materially helps.
- After implementation completes, explicitly spawn `spine_reviewer` for verification.
- Keep trivial edits on the main thread.
- Never run more than one writing subagent at once.
- If subagent tools are unavailable, continue on the main thread and state that fallback explicitly.
"""
EOF

ensure_codex_hooks_flag() {
    local config_file="$1"
    if [ -f "$config_file" ] && ! grep -q "codex_hooks" "$config_file" 2>/dev/null; then
        if grep -q '^\[features\]' "$config_file" 2>/dev/null; then
            awk '
                BEGIN { inserted = 0 }
                /^\[features\]/ {
                    print
                    if (!inserted) {
                        print "codex_hooks = true"
                        inserted = 1
                    }
                    next
                }
                { print }
            ' "$config_file" > "$config_file.tmp"
            mv "$config_file.tmp" "$config_file"
        else
            cat >> "$config_file" << 'TOML'

[features]
codex_hooks = true
TOML
        fi
        info "Enabled codex hooks in: $config_file"
    fi
}

ensure_spine_developer_instructions() {
    local config_file="$1"
    [ -f "$config_file" ] || return 0

    local expected_block
    expected_block=$(printf '%s\n%s\n%s\n' "$SPINE_CONFIG_BEGIN" "$SPINE_DEVELOPER_INSTRUCTIONS" "$SPINE_CONFIG_END")
    awk -v begin="$SPINE_CONFIG_BEGIN" -v end="$SPINE_CONFIG_END" -v block="$expected_block" '
        BEGIN {
            skipping = 0
            inserted = 0
        }
        $0 == begin {
            skipping = 1
            next
        }
        $0 == end {
            skipping = 0
            next
        }
        skipping { next }
        !inserted && /^\[[^]]+\]/ {
            print block
            inserted = 1
        }
        { print }
        END {
            if (!inserted) {
                if (NR > 0) {
                    print ""
                }
                print block
            }
        }
    ' "$config_file" > "$config_file.tmp"

    if cmp -s "$config_file" "$config_file.tmp"; then
        rm -f "$config_file.tmp"
        info "Project Spine developer instructions already current in: $config_file"
        return 0
    fi

    mv "$config_file.tmp" "$config_file"
    info "Updated Project Spine developer instructions in: $config_file"
}

install_hooks_config() {
    mkdir -p ".codex"

    if [ -f ".codex/hooks/hooks.json" ]; then
        rm -f ".codex/hooks/hooks.json"
        info "Migrated legacy hook config path: .codex/hooks/hooks.json"
    fi

    if [ ! -f ".codex/hooks.json" ]; then
        cp "$SCRIPT_DIR/hooks/hooks.json" ".codex/hooks.json"
        info "Created: .codex/hooks.json"
    else
        warn ".codex/hooks.json already exists — skipping (review manually)"
    fi
}

# ── Resolve the directory where this script lives ──
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Pre-flight checks ──
if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    error "Not inside a git repository. Run 'git init' first."
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"
info "Installing Project Spine in: $PROJECT_ROOT"

# ── Step 1: Create .spine/ directory structure ──
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

copy_if_missing "$SCRIPT_DIR/templates/.spine/project.md"      ".spine/project.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/conventions.md"  ".spine/conventions.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/progress.md"     ".spine/progress.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/config.yaml"     ".spine/config.yaml"

if [ ! -f ".spine/active-feature" ]; then
    touch ".spine/active-feature"
    info "Created: .spine/active-feature"
fi

mkdir -p ".spine/features/_template"
copy_if_missing "$SCRIPT_DIR/templates/.spine/features/_template/plan.md"     ".spine/features/_template/plan.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/features/_template/findings.md" ".spine/features/_template/findings.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/features/_template/log.md"      ".spine/features/_template/log.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/features/_template/spec.md"     ".spine/features/_template/spec.md"

# ── Step 2: Copy Codex agent definitions ──
mkdir -p ".codex/agents"
copy_if_missing "$SCRIPT_DIR/.codex/agents/spine-planner.toml"        ".codex/agents/spine-planner.toml"
copy_if_missing "$SCRIPT_DIR/.codex/agents/spine-explorer.toml"       ".codex/agents/spine-explorer.toml"
copy_if_missing "$SCRIPT_DIR/.codex/agents/spine-worker-simple.toml"  ".codex/agents/spine-worker-simple.toml"
copy_if_missing "$SCRIPT_DIR/.codex/agents/spine-worker-complex.toml" ".codex/agents/spine-worker-complex.toml"
copy_if_missing "$SCRIPT_DIR/.codex/agents/spine-reviewer.toml"       ".codex/agents/spine-reviewer.toml"

# ── Step 3: Copy Codex config.toml (merge if exists) ──
CONFIG_CREATED=0
if [ -f ".codex/config.toml" ]; then
    warn ".codex/config.toml exists — preserving user settings, patching Spine-managed block"
else
    copy_if_missing "$SCRIPT_DIR/templates/.codex/config.toml" ".codex/config.toml"
    CONFIG_CREATED=1
fi

ensure_codex_hooks_flag ".codex/config.toml"
if [ "$CONFIG_CREATED" -eq 0 ]; then
    ensure_spine_developer_instructions ".codex/config.toml"
fi

# ── Step 4: Copy skills ──
mkdir -p ".agents/skills/spine-pwf"
mkdir -p ".agents/skills/spine-spec"
copy_if_missing "$SCRIPT_DIR/.agents/skills/spine-pwf/SKILL.md"  ".agents/skills/spine-pwf/SKILL.md"
copy_if_missing "$SCRIPT_DIR/.agents/skills/spine-spec/SKILL.md" ".agents/skills/spine-spec/SKILL.md"

# ── Step 5: Copy hook scripts ──
mkdir -p ".codex/hooks"
for hook in session-start.sh pre-tool-use.sh post-tool-use.sh stop.sh; do
    if [ -f "$SCRIPT_DIR/hooks/$hook" ]; then
        cp "$SCRIPT_DIR/hooks/$hook" ".codex/hooks/$hook"
        chmod +x ".codex/hooks/$hook"
        info "Installed hook: .codex/hooks/$hook"
    fi
done
install_hooks_config

# ── Step 6: Handle AGENTS.md ──
AGENTS_TEMPLATE="$SCRIPT_DIR/templates/AGENTS.md"
SPINE_BEGIN="<!-- BEGIN PROJECT SPINE -->"

if [ -f "AGENTS.md" ]; then
    if grep -q "$SPINE_BEGIN" "AGENTS.md" 2>/dev/null; then
        warn "AGENTS.md already contains Project Spine section — skipping"
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

# ── Step 8: Stage files ──
info "Staging files..."
git add .spine/ .codex/ .agents/ AGENTS.md .gitignore 2>/dev/null || true

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
echo "    .spine/features/_template/ ← Templates for per-feature files"
echo "    .codex/agents/             ← Subagent definitions (planner, explorer, worker-simple, worker-complex, reviewer)"
echo "    .codex/hooks/              ← SessionStart, PreToolUse, PostToolUse, Stop hooks"
echo "    .codex/hooks.json          ← Codex hook configuration"
echo "    .agents/skills/            ← spine-pwf and spine-spec skills"
echo "    AGENTS.md                  ← Workflow instructions for Codex"
echo ""
echo "  Next steps:"
echo "    1. Edit .spine/project.md with your project details"
echo "    2. Edit .spine/conventions.md with your coding conventions"
echo "    3. Run: codex"
echo "    4. Try: \$spine-spec to define a feature"
echo "    5. Say: \$spine-pwf when you're ready to plan and implement"
echo ""
