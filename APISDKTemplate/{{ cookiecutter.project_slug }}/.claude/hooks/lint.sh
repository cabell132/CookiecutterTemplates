#!/bin/bash
# Lint hook - runs ruff, ty, and pydoclint on modified Python files when Claude stops

# Get modified tracked files (staged and unstaged)
modified_files=$(git diff --name-only --diff-filter=ACM HEAD -- '*.py' 2>/dev/null)

# Get untracked Python files
untracked_files=$(git ls-files --others --exclude-standard -- '*.py' 2>/dev/null)

# Combine both lists
all_files=$(echo -e "${modified_files}\n${untracked_files}" | grep -v '^$' | sort -u)

if [ -z "$all_files" ]; then
    exit 0
fi

# Filter out test files for pydoclint (it excludes them via config but pass explicitly)
non_test_files=$(echo "$all_files" | grep -v '^tests/')

has_errors=0

# Run ruff check on all modified/untracked files
ruff_output=$(uv run ruff check $all_files 2>&1)
ruff_exit=$?

if [ $ruff_exit -ne 0 ]; then
    echo "=== Ruff Errors ===" >&2
    echo "$ruff_output" >&2
    has_errors=1
fi

# Run ty type checker on all modified/untracked files
ty_output=$(uv run ty check $all_files 2>&1)
ty_exit=$?

if [ $ty_exit -ne 0 ]; then
    echo "=== ty Type Errors ===" >&2
    echo "$ty_output" >&2
    has_errors=1
fi

# Run pydoclint on non-test files
if [ -n "$non_test_files" ]; then
    pydoclint_output=$(uv run pydoclint $non_test_files 2>&1)
    pydoclint_exit=$?

    if [ $pydoclint_exit -ne 0 ]; then
        echo "=== Pydoclint Errors ===" >&2
        echo "$pydoclint_output" >&2
        has_errors=1
    fi
fi

if [ $has_errors -ne 0 ]; then
    exit 2
fi

exit 0