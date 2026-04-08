#!/usr/bin/env bash
set -euo pipefail

SPINE_DIR=".spine"
FEATURES_DIR="$SPINE_DIR/features"
BACKLOG_DIR="$FEATURES_DIR/backlog"
ACTIVE_FILE="$SPINE_DIR/active-feature"
PROGRESS_FILE="$SPINE_DIR/progress.md"

usage() {
    cat <<EOF
Usage: $(basename "$0") <command> [args]

Commands:
  move <slug>                 Move feature to backlog (updates backreferences)
  activate <slug>             Move feature from backlog to features (checks deps)
  list                        List all backlogged features
  status <slug>               Show dependencies and dependents for a feature

Examples:
  $(basename "$0") move my-feature
  $(basename "$0") activate my-feature
  $(basename "$0") list
  $(basename "$0") status my-feature

EOF
}

read_yaml_list() {
    local file="$1"
    local field="$2"
    local in_frontmatter=false
    local in_field=false
    local items=()

    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if [ "$in_frontmatter" = true ]; then
                break
            fi
            in_frontmatter=true
            continue
        fi
        if [ "$in_frontmatter" = true ]; then
            if [[ "$line" == "${field}:"* ]]; then
                in_field=true
                local val="${line#*:}"
                val="${val// /}"
                if [ "$val" != "[]" ] && [ -n "$val" ]; then
                    items+=("$val")
                fi
                continue
            fi
            if [ "$in_field" = true ]; then
                if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
                    items+=("${BASH_REMATCH[1]}")
                else
                    in_field=false
                fi
            fi
        fi
    done < "$file"

    printf '%s\n' "${items[@]}"
}

yaml_list_contains() {
    local file="$1"
    local field="$2"
    local value="$3"
    local items
    items=$(read_yaml_list "$file" "$field")
    while IFS= read -r item; do
        if [ "$item" = "$value" ]; then
            return 0
        fi
    done <<< "$items"
    return 1
}

add_to_yaml_list() {
    local file="$1"
    local field="$2"
    local value="$3"
    local in_frontmatter=false
    local in_field=false
    local field_found=false
    local added=false
    local result=""

    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if [ "$in_frontmatter" = true ]; then
                if [ "$field_found" = true ] && [ "$added" = false ]; then
                    result+="  - ${value}"$'\n'
                    added=true
                fi
                in_frontmatter=false
                result+="${line}"$'\n'
                continue
            fi
            in_frontmatter=true
            result+="${line}"$'\n'
            continue
        fi
        if [ "$in_frontmatter" = true ]; then
            if [[ "$line" == "${field}:[]" ]]; then
                result+="${field}:"$'\n'
                result+="  - ${value}"$'\n'
                field_found=true
                added=true
                in_field=true
                continue
            fi
            if [[ "$line" == "${field}:"* ]]; then
                local val="${line#*:}"
                val="${val// /}"
                if [ "$val" = "[]" ]; then
                    result+="${field}:"$'\n'
                    result+="  - ${value}"$'\n'
                    added=true
                else
                    result+="${line}"$'\n'
                fi
                field_found=true
                in_field=true
                continue
            fi
            if [ "$in_field" = true ]; then
                if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+ ]]; then
                    result+="${line}"$'\n'
                    continue
                else
                    if [ "$added" = false ]; then
                        result+="  - ${value}"$'\n'
                        added=true
                    fi
                    in_field=false
                fi
            fi
        fi
        result+="${line}"$'\n'
    done < "$file"

    printf '%s' "$result" > "$file"
}

remove_from_yaml_list() {
    local file="$1"
    local field="$2"
    local value="$3"
    local in_frontmatter=false
    local in_field=false
    local result=""

    while IFS= read -r line; do
        if [[ "$line" == "---" ]]; then
            if [ "$in_frontmatter" = true ]; then
                in_frontmatter=false
                result+="${line}"$'\n'
                continue
            fi
            in_frontmatter=true
            result+="${line}"$'\n'
            continue
        fi
        if [ "$in_frontmatter" = true ]; then
            if [[ "$line" == "${field}:"* ]]; then
                in_field=true
                result+="${line}"$'\n'
                continue
            fi
            if [ "$in_field" = true ]; then
                if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+${value}$ ]]; then
                    continue
                fi
                if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+ ]]; then
                    result+="${line}"$'\n'
                    continue
                else
                    in_field=false
                fi
            fi
        fi
        result+="${line}"$'\n'
    done < "$file"

    printf '%s' "$result" > "$file"
}

find_feature_dir() {
    local slug="$1"
    if [ -d "$FEATURES_DIR/$slug" ]; then
        echo "$FEATURES_DIR/$slug"
        return 0
    fi
    if [ -d "$BACKLOG_DIR/$slug" ]; then
        echo "$BACKLOG_DIR/$slug"
        return 0
    fi
    return 1
}

update_dependents() {
    local slug="$1"
    local spec_file="$2"

    local deps
    deps=$(read_yaml_list "$spec_file" "dependencies")

    while IFS= read -r dep_slug; do
        [ -n "$dep_slug" ] || continue
        local dep_dir
        dep_dir=$(find_feature_dir "$dep_slug") || {
            echo "  WARNING: dependency '$dep_slug' not found, skipping backreference update"
            continue
        }
        local dep_spec="$dep_dir/spec.md"
        if [ ! -f "$dep_spec" ]; then
            echo "  WARNING: no spec.md for '$dep_slug', skipping backreference update"
            continue
        fi
        if ! yaml_list_contains "$dep_spec" "dependents" "$slug"; then
            add_to_yaml_list "$dep_spec" "dependents" "$slug"
            echo "  Updated dependents in $dep_spec: +$slug"
        fi
    done <<< "$deps"
}

remove_dependents_ref() {
    local slug="$1"
    local spec_file="$2"

    local deps
    deps=$(read_yaml_list "$spec_file" "dependencies")

    while IFS= read -r dep_slug; do
        [ -n "$dep_slug" ] || continue
        local dep_dir
        dep_dir=$(find_feature_dir "$dep_slug") || continue
        local dep_spec="$dep_dir/spec.md"
        [ -f "$dep_spec" ] || continue
        if yaml_list_contains "$dep_spec" "dependents" "$slug"; then
            remove_from_yaml_list "$dep_spec" "dependents" "$slug"
            echo "  Updated dependents in $dep_spec: -$slug"
        fi
    done <<< "$deps"
}

scan_dependents_of() {
    local slug="$1"
    local spec_file="$2"

    local search_dirs=("$FEATURES_DIR" "$BACKLOG_DIR")
    for search_dir in "${search_dirs[@]}"; do
        [ -d "$search_dir" ] || continue
        for dir in "$search_dir"/*/; do
            [ -d "$dir" ] || continue
            local other_slug
            other_slug=$(basename "$dir")
            [ "$other_slug" = "_template" ] && continue
            [ "$other_slug" = "backlog" ] && continue
            [ "$other_slug" = "$slug" ] && continue
            local other_spec="$dir/spec.md"
            [ -f "$other_spec" ] || continue
            if yaml_list_contains "$other_spec" "dependencies" "$slug"; then
                if ! yaml_list_contains "$spec_file" "dependents" "$other_slug"; then
                    add_to_yaml_list "$spec_file" "dependents" "$other_slug"
                    echo "  Updated dependents in $spec_file: +$other_slug"
                fi
            fi
        done
    done
}

remove_from_progress() {
    local slug="$1"
    [ -f "$PROGRESS_FILE" ] || return 0
    sed -i "/^- ${slug}$/d" "$PROGRESS_FILE" 2>/dev/null || true
    sed -i "/^- \[.\] ${slug}$/d" "$PROGRESS_FILE" 2>/dev/null || true
}

move_to_backlog() {
    local slug="$1"
    local feat_dir="$FEATURES_DIR/$slug"

    if [ ! -d "$feat_dir" ]; then
        echo "Feature not found in active features: $slug"
        exit 1
    fi

    if [ -d "$BACKLOG_DIR/$slug" ]; then
        echo "Feature already in backlog: $slug"
        exit 1
    fi

    local spec_file="$feat_dir/spec.md"

    echo "Moving feature to backlog: $slug"

    if [ -f "$spec_file" ]; then
        update_dependents "$slug" "$spec_file"
        scan_dependents_of "$slug" "$spec_file"
    fi

    mkdir -p "$BACKLOG_DIR"
    mv "$feat_dir" "$BACKLOG_DIR/$slug"
    echo "  Moved: $feat_dir -> $BACKLOG_DIR/$slug"

    remove_from_progress "$slug"

    if [ -f "$ACTIVE_FILE" ] && [ "$(tr -d '[:space:]' < "$ACTIVE_FILE" 2>/dev/null)" = "$slug" ]; then
        > "$ACTIVE_FILE"
        echo "  Cleared active-feature (was: $slug)"
    fi

    echo "Done."
}

activate_from_backlog() {
    local slug="$1"
    local back_dir="$BACKLOG_DIR/$slug"

    if [ ! -d "$back_dir" ]; then
        echo "Feature not found in backlog: $slug"
        exit 1
    fi

    if [ -d "$FEATURES_DIR/$slug" ]; then
        echo "Feature already active: $slug"
        exit 1
    fi

    local spec_file="$back_dir/spec.md"

    if [ -f "$spec_file" ]; then
        local deps
        deps=$(read_yaml_list "$spec_file" "dependencies")
        local blocked=false
        while IFS= read -r dep_slug; do
            [ -n "$dep_slug" ] || continue
            if [ -d "$BACKLOG_DIR/$dep_slug" ]; then
                echo "  BLOCKED: dependency '$dep_slug' is still in backlog"
                blocked=true
            fi
        done <<< "$deps"
        if [ "$blocked" = true ]; then
            echo "Cannot activate: unresolved dependencies in backlog."
            echo "Activate dependencies first, or remove them from the feature's dependencies list."
            exit 1
        fi
    fi

    echo "Activating feature from backlog: $slug"

    mv "$back_dir" "$FEATURES_DIR/$slug"
    echo "  Moved: $back_dir -> $FEATURES_DIR/$slug"

    remove_from_progress "$slug"

    echo "Done."
}

list_backlog() {
    if [ ! -d "$BACKLOG_DIR" ]; then
        echo "No backlog directory found."
        return
    fi

    local count=0
    echo "Backlog:"
    echo "========"

    for dir in "$BACKLOG_DIR"/*/; do
        [ -d "$dir" ] || continue
        local slug
        slug=$(basename "$dir")
        echo "  $slug"
        if [ -f "$dir/spec.md" ]; then
            local deps
            deps=$(read_yaml_list "$dir/spec.md" "dependencies")
            if [ -n "$deps" ]; then
                echo "    dependencies: $(echo "$deps" | tr '\n' ', ' | sed 's/,$//')"
            fi
            local dependents
            dependents=$(read_yaml_list "$dir/spec.md" "dependents")
            if [ -n "$dependents" ]; then
                echo "    dependents: $(echo "$dependents" | tr '\n' ', ' | sed 's/,$//')"
            fi
        fi
        count=$((count + 1))
    done

    if [ "$count" -eq 0 ]; then
        echo "  (empty)"
    fi
    echo ""
}

show_status() {
    local slug="$1"
    local feat_dir
    feat_dir=$(find_feature_dir "$slug") || {
        echo "Feature not found: $slug"
        exit 1
    }

    local location="active"
    if [[ "$feat_dir" == *"/backlog/"* ]]; then
        location="backlog"
    fi

    echo "Feature: $slug ($location)"

    local spec_file="$feat_dir/spec.md"
    if [ ! -f "$spec_file" ]; then
        echo "  No spec.md found"
        return
    fi

    local deps
    deps=$(read_yaml_list "$spec_file" "dependencies")
    echo "  Dependencies:"
    if [ -n "$deps" ]; then
        while IFS= read -r dep; do
            [ -n "$dep" ] || continue
            local dep_loc="unknown"
            if [ -d "$FEATURES_DIR/$dep" ]; then
                dep_loc="active"
            elif [ -d "$BACKLOG_DIR/$dep" ]; then
                dep_loc="backlog"
            fi
            echo "    - $dep ($dep_loc)"
        done <<< "$deps"
    else
        echo "    (none)"
    fi

    local dependents
    dependents=$(read_yaml_list "$spec_file" "dependents")
    echo "  Dependents:"
    if [ -n "$dependents" ]; then
        while IFS= read -r dep; do
            [ -n "$dep" ] || continue
            local dep_loc="unknown"
            if [ -d "$FEATURES_DIR/$dep" ]; then
                dep_loc="active"
            elif [ -d "$BACKLOG_DIR/$dep" ]; then
                dep_loc="backlog"
            fi
            echo "    - $dep ($dep_loc)"
        done <<< "$dependents"
    else
        echo "    (none)"
    fi
}

main() {
    if [ $# -eq 0 ]; then
        usage
        exit 1
    fi

    local cmd="$1"
    shift

    case "$cmd" in
        move)
            if [ $# -lt 1 ]; then
                echo "Error: slug required"
                usage
                exit 1
            fi
            move_to_backlog "$1"
            ;;
        activate)
            if [ $# -lt 1 ]; then
                echo "Error: slug required"
                usage
                exit 1
            fi
            activate_from_backlog "$1"
            ;;
        list)
            list_backlog
            ;;
        status)
            if [ $# -lt 1 ]; then
                echo "Error: slug required"
                usage
                exit 1
            fi
            show_status "$1"
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
