#!/usr/bin/env bash
set -euo pipefail

SPINE_DIR=".spine"
FEATURES_DIR="$SPINE_DIR/features"
ACTIVE_FILE="$SPINE_DIR/active-feature"
PROGRESS_FILE="$SPINE_DIR/progress.md"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  list                        List all features with status
  remove <slug>               Remove a feature directory and update progress
  clear-active               Clear the active-feature marker
  prune [--dry-run]          Remove stale features (no spec.md or stuck in-progress)
  reset <slug>               Remove feature and clear active if it's that feature

Examples:
  $(basename "$0") list
  $(basename "$0") remove my-feature
  $(basename "$0") prune --dry-run
  $(basename "$0") reset my-feature

EOF
}

list_features() {
    if [ ! -d "$FEATURES_DIR" ]; then
        echo "No features directory found."
        return
    fi

    echo "Features:"
    echo "========="
    
    active_slug=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "")
    
    for dir in "$FEATURES_DIR"/*/; do
        [ -d "$dir" ] || continue
        slug=$(basename "$dir")
        
        if [ "$slug" = "_template" ]; then
            continue
        fi
        
        status="unknown"
        if [ -f "$dir/spec.md" ]; then
            status="specced"
        fi
        if [ -f "$dir/plan.md" ]; then
            status="planned"
        fi
        if grep -q "Status:.*complete" "$dir/plan.md" 2>/dev/null; then
            status="complete"
        elif grep -q "Status:.*in.progress" "$dir/plan.md" 2>/dev/null; then
            status="in.progress"
        fi
        
        active_mark=""
        if [ "$slug" = "$active_slug" ]; then
            active_mark=" [ACTIVE]"
        fi
        
        echo "  $slug$active_mark ($status)"
        echo "    → $dir"
    done
    echo ""
}

remove_feature() {
    local slug="$1"
    local feat_dir="$FEATURES_DIR/$slug"
    
    if [ ! -d "$feat_dir" ]; then
        echo "Feature not found: $slug"
        exit 1
    fi
    
    echo "Removing feature: $slug"
    rm -rf "$feat_dir"
    echo "  Removed: $feat_dir"
    
    if [ -f "$PROGRESS_FILE" ]; then
        sed -i "/^- \[ \] $slug$/d" "$PROGRESS_FILE" 2>/dev/null || true
        sed -i "/^- \[x\] $slug$/d" "$PROGRESS_FILE" 2>/dev/null || true
        echo "  Updated: $PROGRESS_FILE"
    fi
    
    if [ -f "$ACTIVE_FILE" ] && [ "$(cat "$ACTIVE_FILE")" = "$slug" ]; then
        rm -f "$ACTIVE_FILE"
        touch "$ACTIVE_FILE"
        echo "  Cleared active-feature (was: $slug)"
    fi
    
    echo "Done."
}

clear_active() {
    if [ ! -f "$ACTIVE_FILE" ]; then
        echo "No active-feature file found."
        return
    fi
    
    local active_slug=$(cat "$ACTIVE_FILE" 2>/dev/null || echo "")
    if [ -z "$active_slug" ]; then
        echo "No active feature."
        return
    fi
    
    echo "Clearing active feature: $active_slug"
    > "$ACTIVE_FILE"
    echo "Done."
}

prune_features() {
    local dry_run=false
    if [ "${1:-}" = "--dry-run" ]; then
        dry_run=true
        echo "DRY RUN - no changes will be made"
        echo ""
    fi
    
    if [ ! -d "$FEATURES_DIR" ]; then
        echo "No features directory found."
        return
    fi
    
    echo "Checking for stale features..."
    echo ""
    
    for dir in "$FEATURES_DIR"/*/; do
        [ -d "$dir" ] || continue
        slug=$(basename "$dir")
        
        if [ "$slug" = "_template" ]; then
            continue
        fi
        
        stale_reason=""
        
        if [ ! -f "$dir/spec.md" ] && [ ! -f "$dir/plan.md" ]; then
            stale_reason="no spec.md or plan.md"
        elif [ ! -f "$dir/spec.md" ] && [ -f "$dir/plan.md" ]; then
            stale_reason="has plan.md but no spec.md (incomplete spec flow)"
        elif [ -f "$dir/spec.md" ] && [ ! -f "$dir/plan.md" ]; then
            stale_reason="has spec.md but no plan.md (never planned)"
        fi
        
        if [ -n "$stale_reason" ]; then
            echo "  STALE: $slug"
            echo "    Reason: $stale_reason"
            echo "    Path: $dir"
            
            if [ "$dry_run" = false ]; then
                rm -rf "$dir"
                echo "    → Removed"
                
                if [ -f "$PROGRESS_FILE" ]; then
                    sed -i "/^- \[ \] $slug$/d" "$PROGRESS_FILE" 2>/dev/null || true
                    sed -i "/^- \[x\] $slug$/d" "$PROGRESS_FILE" 2>/dev/null || true
                fi
                
                if [ -f "$ACTIVE_FILE" ] && [ "$(cat "$ACTIVE_FILE")" = "$slug" ]; then
                    > "$ACTIVE_FILE"
                    echo "    → Cleared active-feature (was: $slug)"
                fi
            fi
            echo ""
        fi
    done
    
    echo "Prune complete."
}

reset_feature() {
    local slug="$1"
    local feat_dir="$FEATURES_DIR/$slug"
    
    if [ -d "$feat_dir" ]; then
        echo "Resetting feature: $slug"
        rm -rf "$feat_dir"
        echo "  Removed: $feat_dir"
    else
        echo "Feature directory not found: $slug (will only clear active)"
    fi
    
    if [ -f "$PROGRESS_FILE" ]; then
        sed -i "/^- \[ \] $slug$/d" "$PROGRESS_FILE" 2>/dev/null || true
        sed -i "/^- \[x\] $slug$/d" "$PROGRESS_FILE" 2>/dev/null || true
        echo "  Updated: $PROGRESS_FILE"
    fi
    
    if [ -f "$ACTIVE_FILE" ] && [ "$(cat "$ACTIVE_FILE")" = "$slug" ]; then
        > "$ACTIVE_FILE"
        echo "  Cleared active-feature (was: $slug)"
    fi
    
    echo "Done."
}

main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi
    
    cmd="$1"
    shift
    
    case "$cmd" in
        list)
            list_features
            ;;
        remove)
            if [ $# -lt 1 ]; then
                echo "Error: slug required"
                usage
                exit 1
            fi
            remove_feature "$1"
            ;;
        clear-active)
            clear_active
            ;;
        prune)
            prune_features "$@"
            ;;
        reset)
            if [ $# -lt 1 ]; then
                echo "Error: slug required"
                usage
                exit 1
            fi
            reset_feature "$1"
            ;;
        -h|--help|help)
            usage
            ;;
        *)
            echo "Unknown command: $cmd"
            usage
            exit 1
            ;;
    esac
}

main "$@"