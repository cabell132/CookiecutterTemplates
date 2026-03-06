#!/bin/bash
# PreToolUse hook: No logic in __init__.py — imports and __all__ only

input=$(cat)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[ -z "$file_path" ] && exit 0

# Only check __init__.py files
[[ "$(basename "$file_path")" != "__init__.py" ]] && exit 0

# Get the content being written/edited
content=$(echo "$input" | jq -r '.tool_input.content // .tool_input.new_string // empty')

[ -z "$content" ] && exit 0

# Strip comments, docstrings (simple), blank lines, imports, __all__, and __version__
# Check if anything remains that looks like logic
logic=$(echo "$content" | \
    sed '/^[[:space:]]*#/d' | \
    sed '/^[[:space:]]*$/d' | \
    sed '/^[[:space:]]*""".*"""[[:space:]]*$/d' | \
    sed '/^[[:space:]]*'"'"''"'"''"'"'.*'"'"''"'"''"'"'[[:space:]]*$/d' | \
    sed '/^"""/,/^"""/d' | \
    sed "/^'''/,/^'''/d" | \
    sed '/^[[:space:]]*from /d' | \
    sed '/^[[:space:]]*import /d' | \
    sed '/^[[:space:]]*__all__[[:space:]]*=/d' | \
    sed '/^[[:space:]]*__version__[[:space:]]*=/d' | \
    grep -v '^[[:space:]]*$')

if [ -n "$logic" ]; then
    echo "No logic in __init__.py — imports and __all__ only." >&2
    echo "Detected non-import content:" >&2
    echo "$logic" | head -5 >&2
    exit 2
fi

exit 0
