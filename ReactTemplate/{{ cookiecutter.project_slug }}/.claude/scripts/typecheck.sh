#!/usr/bin/env bash
# Stop hook: Run TypeScript type checking on the whole project

output=$({% if cookiecutter.node_package_manager == "bun" %}bunx{% elif cookiecutter.node_package_manager == "pnpm" %}pnpm exec{% else %}npx{% endif %} tsc --noEmit 2>&1)
if [ $? -ne 0 ]; then
    line_count=$(echo "$output" | wc -l)
    if [ "$line_count" -gt 30 ]; then
        mkdir -p .claude
        echo "$output" > .claude/check-output.log
        echo "=== TypeScript Errors ($line_count lines — truncated) ===" >&2
        echo "$output" | head -20 >&2
        echo "..." >&2
        echo "Full output saved to .claude/check-output.log" >&2
    else
        echo "=== TypeScript Errors ===" >&2
        echo "$output" >&2
    fi
    exit 2
fi
exit 0
