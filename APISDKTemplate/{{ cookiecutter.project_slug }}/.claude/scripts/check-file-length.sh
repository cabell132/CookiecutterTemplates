#!/bin/bash
# PostToolUse hook: Block Python files exceeding 300 lines

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[ -z "$file_path" ] && exit 0
[[ "$file_path" != *.py ]] && exit 0
[ ! -f "$file_path" ] && exit 0

line_count=$(wc -l < "$file_path")

if [ "$line_count" -gt 300 ]; then
    echo "File exceeds 300 lines ($line_count lines). Split into smaller modules." >&2
    exit 2
fi

exit 0
