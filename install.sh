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

# Project-level files
copy_if_missing "$SCRIPT_DIR/templates/.spine/project.md"      ".spine/project.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/conventions.md"   ".spine/conventions.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/progress.md"      ".spine/progress.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/config.yaml"      ".spine/config.yaml"

# Active feature tracker
if [ ! -f ".spine/active-feature" ]; then
    touch ".spine/active-feature"
    info "Created: .spine/active-feature"
fi

# Feature templates
mkdir -p ".spine/features/_template"
copy_if_missing "$SCRIPT_DIR/templates/.spine/features/_template/plan.md"     ".spine/features/_template/plan.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/features/_template/findings.md" ".spine/features/_template/findings.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/features/_template/log.md"      ".spine/features/_template/log.md"
copy_if_missing "$SCRIPT_DIR/templates/.spine/features/_template/spec.md"     ".spine/features/_template/spec.md"

# ── Step 2: Copy Codex agent definitions ──
mkdir -p ".codex/agents"
copy_if_missing "$SCRIPT_DIR/.codex/agents/spine-explorer.toml" ".codex/agents/spine-explorer.toml"
copy_if_missing "$SCRIPT_DIR/.codex/agents/spine-worker.toml"   ".codex/agents/spine-worker.toml"
copy_if_missing "$SCRIPT_DIR/.codex/agents/spine-reviewer.toml" ".codex/agents/spine-reviewer.toml"

# ── Step 3: Copy Codex config.toml (merge if exists) ──
if [ -f ".codex/config.toml" ]; then
    # Check if spine agent config already present
    if grep -q "spine" ".codex/config.toml" 2>/dev/null; then
        warn ".codex/config.toml already contains spine config — skipping"
    else
        warn ".codex/config.toml exists — appending spine agent settings"
        cat >> ".codex/config.toml" << 'TOML'

# ── Project Spine settings ──
[agents]
max_threads = 4
max_depth = 1
TOML
        info "Appended agent settings to .codex/config.toml"
    fi
else
    copy_if_missing "$SCRIPT_DIR/templates/.codex/config.toml" ".codex/config.toml"
fi

# ── Step 4: Copy skills ──
mkdir -p ".agents/skills/spine-pwf"
mkdir -p ".agents/skills/spine-spec"
copy_if_missing "$SCRIPT_DIR/.agents/skills/spine-pwf/SKILL.md"  ".agents/skills/spine-pwf/SKILL.md"
copy_if_missing "$SCRIPT_DIR/.agents/skills/spine-spec/SKILL.md" ".agents/skills/spine-spec/SKILL.md"

# ── Step 5: Copy hook scripts ──
mkdir -p ".codex/hooks"
for hook in pre-tool-use.sh post-tool-use.sh stop.sh; do
    if [ -f "$SCRIPT_DIR/hooks/$hook" ]; then
        cp "$SCRIPT_DIR/hooks/$hook" ".codex/hooks/$hook"
        chmod +x ".codex/hooks/$hook"
        info "Installed hook: .codex/hooks/$hook"
    fi
done

# Create hooks configuration for Codex
if [ ! -f ".codex/hooks/hooks.json" ]; then
    cat > ".codex/hooks/hooks.json" << 'JSON'
{
  "hooks": [
    {
      "type": "pre-tool-use",
      "event": ["write", "edit", "shell", "read"],
      "command": ".codex/hooks/pre-tool-use.sh",
      "timeout": 5000
    },
    {
      "type": "post-tool-use",
      "event": ["write", "edit"],
      "command": ".codex/hooks/post-tool-use.sh",
      "timeout": 3000
    },
    {
      "type": "stop",
      "command": ".codex/hooks/stop.sh",
      "timeout": 5000
    }
  ]
}
JSON
    info "Created: .codex/hooks/hooks.json"
else
    warn ".codex/hooks/hooks.json already exists — skipping (review manually)"
fi

# ── Step 6: Handle AGENTS.md ──
AGENTS_TEMPLATE="$SCRIPT_DIR/templates/AGENTS.md"
SPINE_BEGIN="<!-- BEGIN PROJECT SPINE -->"
SPINE_END="<!-- END PROJECT SPINE -->"

if [ -f "AGENTS.md" ]; then
    # Check if spine section already exists
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
echo "    .codex/agents/             ← Subagent definitions (explorer, worker, reviewer)"
echo "    .codex/hooks/              ← PreToolUse, PostToolUse, Stop hooks"
echo "    .agents/skills/            ← spine-pwf and spine-spec skills"
echo "    AGENTS.md                  ← Workflow instructions for Codex"
echo ""
echo "  Next steps:"
echo "    1. Edit .spine/project.md with your project details"
echo "    2. Edit .spine/conventions.md with your coding conventions"
echo "    3. Run: codex"
echo "    4. Try: \$spine-spec to define a feature"
echo "    5. Or just describe a feature and the workflow activates automatically"
echo ""
