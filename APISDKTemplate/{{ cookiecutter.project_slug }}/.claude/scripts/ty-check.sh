#!/bin/bash
# Stop hook: Run ty type checker (respects [tool.ty.src] in pyproject.toml)

output=$(uv run ty check 2>&1)
if [ $? -ne 0 ]; then
    line_count=$(echo "$output" | wc -l)
    if [ "$line_count" -gt 30 ]; then
        mkdir -p .claude
        echo "$output" > .claude/check-output.log
        echo "=== ty Type Errors ($line_count lines — truncated) ===" >&2
        echo "$output" | head -20 >&2
        echo "..." >&2
        echo "Full output saved to .claude/check-output.log" >&2
    else
        echo "=== ty Type Errors ===" >&2
        echo "$output" >&2
    fi
    exit 2
fi

exit 0
