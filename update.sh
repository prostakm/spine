#!/usr/bin/env bash
set -euo pipefail

# Project Spine — Update Script
# Uses the shared installer path so install/update never drift.

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

info()  { echo -e "${GREEN}[spine]${NC} $1"; }
error() { echo -e "${RED}[spine]${NC} $1"; exit 1; }

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
info "Delegating to install.sh so managed files stay in sync"

exec "$SCRIPT_DIR/install.sh"
