#!/usr/bin/env bash
# Stop hook: Run biome lint check on all modified TS/JS files (report only)

modified_files=$(git diff --name-only --diff-filter=ACM HEAD -- '*.ts' '*.tsx' '*.js' '*.jsx' 2>/dev/null)
untracked_files=$(git ls-files --others --exclude-standard -- '*.ts' '*.tsx' '*.js' '*.jsx' 2>/dev/null)
all_files=$(echo -e "${modified_files}\n${untracked_files}" | grep -v '^$' | sort -u)

[ -z "$all_files" ] && exit 0

output=$({% if cookiecutter.node_package_manager == "bun" %}bunx{% elif cookiecutter.node_package_manager == "pnpm" %}pnpm exec{% else %}npx{% endif %} biome check $all_files 2>&1)
if [ $? -ne 0 ]; then
    line_count=$(echo "$output" | wc -l)
    if [ "$line_count" -gt 30 ]; then
        mkdir -p .claude
        echo "$output" > .claude/check-output.log
        echo "=== Biome Errors ($line_count lines — truncated) ===" >&2
        echo "$output" | head -20 >&2
        echo "..." >&2
        echo "Full output saved to .claude/check-output.log" >&2
    else
        echo "=== Biome Errors ===" >&2
        echo "$output" >&2
    fi
    exit 2
fi

exit 0
