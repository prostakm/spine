#!/usr/bin/env bash
set -euo pipefail

DOC="${1:-}"
LABEL="${2:-document}"
MAX_WIDTH=100

if [ -z "$DOC" ]; then
    echo "Usage: validate-spine-doc.sh <doc.md> [label]" >&2
    exit 1
fi

if [ ! -f "$DOC" ]; then
    echo "Error: $DOC not found" >&2
    exit 1
fi

awk -v max_width="$MAX_WIDTH" -v label="$LABEL" '
BEGIN {
    in_code = 0
    errors = 0
    warnings = 0
}

function is_url_only(line) {
    return line ~ /^https?:\/\// || line ~ /^<https?:\/\//
}

function is_whole_line_bold(line, count, tmp) {
    tmp = line
    count = gsub(/\*\*/, "", tmp)
    return count == 2 && line ~ /^\*\*.*\*\*$/
}

{
    line = $0

    if (line ~ /^```/) {
        in_code = !in_code
        next
    }

    if (in_code) {
        next
    }

    trimmed = line
    sub(/^[[:space:]]+/, "", trimmed)
    sub(/[[:space:]]+$/, "", trimmed)

    if (length(line) > max_width && !is_url_only(trimmed)) {
        printf "%s:%d exceeds %d chars (%d)\n", label, NR, max_width, length(line) \
            > "/dev/stderr"
        errors += 1
    }

    if (trimmed != "" && trimmed !~ /^<!--/ && trimmed !~ /^#/ &&
        is_whole_line_bold(trimmed)) {
        printf "%s:%d warning: whole-line bold; highlight only the crucial fragment\n", \
            label, NR > "/dev/stderr"
        warnings += 1
    }
}

END {
    if (warnings > 0) {
        printf "%s: %d bold-style warning(s); fix if the emphasis is noisy\n", \
            label, warnings > "/dev/stderr"
    }
    exit(errors > 0)
}
' "$DOC"
