#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────
# Project Spine — Update Script
# Updates framework files without touching user content.
# ─────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[spine]${NC} $1"; }
warn()  { echo -e "${YELLOW}[spine]${NC} $1"; }
skip()  { echo -e "${CYAN}[spine]${NC} $1"; }
error() { echo -e "${RED}[spine]${NC} $1"; exit 1; }

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

install_hooks_config() {
    mkdir -p ".codex"
    update_file "$SCRIPT_DIR/hooks/hooks.json" ".codex/hooks.json"

    if [ -f ".codex/hooks/hooks.json" ]; then
        rm -f ".codex/hooks/hooks.json"
        info "Removed legacy hook config: .codex/hooks/hooks.json"
    fi
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! git rev-parse --is-inside-work-tree > /dev/null 2>&1; then
    error "Not inside a git repository."
fi

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

if [ ! -d ".spine" ]; then
    error "No .spine/ directory found. Run install.sh first."
fi

info "Updating Project Spine in: $PROJECT_ROOT"
echo ""

echo -e "${CYAN}Will update:${NC}  hooks, skills, agents, templates, AGENTS.md spine section, .codex/config.toml spine block"
echo -e "${CYAN}Won't touch:${NC} project.md, conventions.md, progress.md, config.yaml, features/*"
echo ""

update_file() {
    local src="$1" dst="$2"
    if [ ! -f "$dst" ]; then
        mkdir -p "$(dirname "$dst")"
        cp "$src" "$dst"
        info "Added: $dst"
    elif ! diff -q "$src" "$dst" > /dev/null 2>&1; then
        cp "$src" "$dst"
        info "Updated: $dst"
    else
        skip "Unchanged: $dst"
    fi
}

echo -e "\n${GREEN}── Hooks ──${NC}"
mkdir -p ".codex/hooks"
for hook in session-start.sh pre-tool-use.sh post-tool-use.sh stop.sh; do
    if [ -f "$SCRIPT_DIR/hooks/$hook" ]; then
        update_file "$SCRIPT_DIR/hooks/$hook" ".codex/hooks/$hook"
        chmod +x ".codex/hooks/$hook"
    fi
done
install_hooks_config

echo -e "\n${GREEN}── Skills ──${NC}"
mkdir -p ".agents/skills/spine-pwf" ".agents/skills/spine-spec"
update_file "$SCRIPT_DIR/.agents/skills/spine-pwf/SKILL.md"  ".agents/skills/spine-pwf/SKILL.md"
update_file "$SCRIPT_DIR/.agents/skills/spine-spec/SKILL.md" ".agents/skills/spine-spec/SKILL.md"

echo -e "\n${GREEN}── Templates ──${NC}"
mkdir -p ".spine/features/_template"
for tmpl in plan.md findings.md log.md spec.md; do
    update_file "$SCRIPT_DIR/templates/.spine/features/_template/$tmpl" ".spine/features/_template/$tmpl"
done

echo -e "\n${GREEN}── AGENTS.md ──${NC}"
SPINE_BEGIN="<!-- BEGIN PROJECT SPINE -->"
SPINE_END="<!-- END PROJECT SPINE -->"

if [ ! -f "AGENTS.md" ]; then
    cp "$SCRIPT_DIR/templates/AGENTS.md" "AGENTS.md"
    info "Created: AGENTS.md"
elif grep -q "$SPINE_BEGIN" "AGENTS.md" && grep -q "$SPINE_END" "AGENTS.md"; then
    BEFORE=$(sed "/$SPINE_BEGIN/q" "AGENTS.md")
    AFTER=$(sed -n "/$SPINE_END/,\$p" "AGENTS.md" | tail -n +2)
    NEW_SECTION=$(cat "$SCRIPT_DIR/templates/AGENTS.md")

    {
        echo "$BEFORE"
        echo "$NEW_SECTION" | tail -n +2
        echo "$AFTER"
    } > "AGENTS.md.tmp"

    if ! diff -q "AGENTS.md" "AGENTS.md.tmp" > /dev/null 2>&1; then
        mv "AGENTS.md.tmp" "AGENTS.md"
        info "Updated: AGENTS.md (spine section replaced)"
    else
        rm "AGENTS.md.tmp"
        skip "Unchanged: AGENTS.md"
    fi
else
    warn "AGENTS.md exists but missing spine markers — appending"
    echo "" >> "AGENTS.md"
    echo "---" >> "AGENTS.md"
    echo "" >> "AGENTS.md"
    cat "$SCRIPT_DIR/templates/AGENTS.md" >> "AGENTS.md"
    info "Appended spine section to AGENTS.md"
fi

echo -e "\n${GREEN}── Project files (create only if missing) ──${NC}"
for f in project.md conventions.md progress.md config.yaml; do
    if [ ! -f ".spine/$f" ]; then
        cp "$SCRIPT_DIR/templates/.spine/$f" ".spine/$f"
        info "Created missing: .spine/$f"
    else
        skip "Exists: .spine/$f"
    fi
done
[ ! -f ".spine/active-feature" ] && touch ".spine/active-feature"
ensure_codex_hooks_flag ".codex/config.toml"

echo ""
echo -e "${GREEN}╭──────────────────────────────────────────╮${NC}"
echo -e "${GREEN}│  Project Spine updated                   │${NC}"
echo -e "${GREEN}╰──────────────────────────────────────────╯${NC}"
echo ""
echo "  Review changes: git diff --stat"
echo "  Stage: git add .spine/ .codex/ .agents/ AGENTS.md"
echo ""
