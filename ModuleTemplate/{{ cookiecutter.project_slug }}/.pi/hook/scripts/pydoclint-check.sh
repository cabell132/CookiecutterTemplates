#!/bin/bash
# PostToolUse hook: Run pydoclint on the edited Python file (skip test files)

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_args.file_path // .tool_args.path // .tool_input.file_path // .tool_input.path // empty')

if [ -z "$file_path" ]; then
    modified_files=$(git diff --name-only --diff-filter=ACM HEAD -- '*.py' 2>/dev/null)
    untracked_files=$(git ls-files --others --exclude-standard -- '*.py' 2>/dev/null)
    file_path=$(echo -e "${modified_files}\n${untracked_files}" | grep -v '^$' | grep -vE '(^tests/|/tests/)' | sort -u | tr '\n' ' ')
fi

[ -z "$file_path" ] && exit 0

for path in $file_path; do
    [[ "$path" != *.py ]] && continue
    [ ! -f "$path" ] && continue
    echo "$path" | grep -qE '(^tests/|/tests/)' && continue
    files="$files $path"
done

[ -z "$files" ] && exit 0

output=$(uv run pydoclint $files 2>&1)
if [ $? -ne 0 ]; then
    line_count=$(echo "$output" | wc -l)
    if [ "$line_count" -gt 30 ]; then
        mkdir -p .pi/hook
        echo "$output" > .pi/hook/check-output.log
        echo "=== Pydoclint Errors ($line_count lines — truncated) ===" >&2
        echo "$output" | head -20 >&2
        echo "..." >&2
        echo "Full output saved to .pi/hook/check-output.log" >&2
    else
        echo "=== Pydoclint Errors ===" >&2
        echo "$output" >&2
    fi
    exit 2
fi

exit 0
