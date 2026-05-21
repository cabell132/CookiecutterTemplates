#!/bin/bash
# Stop hook: Verify test file naming convention

modified_files=$(git diff --name-only --diff-filter=ACM HEAD -- '*.py' 2>/dev/null)
untracked_files=$(git ls-files --others --exclude-standard -- '*.py' 2>/dev/null)
all_files=$(echo -e "${modified_files}\n${untracked_files}" | grep -v '^$' | sort -u)

[ -z "$all_files" ] && exit 0

violations=""
for file_path in $all_files; do
    # Check if path is inside a tests directory
    if echo "$file_path" | grep -q '/tests/'; then
        filename=$(basename "$file_path")
        if [[ "$filename" != test_* ]] && [[ "$filename" != conftest.py ]] && [[ "$filename" != __init__.py ]]; then
            violations="${violations}${file_path}: test files must be named test_*.py (got '${filename}')\n"
        fi
    fi
done

if [ -n "$violations" ]; then
    echo "=== Test Naming Violations ===" >&2
    echo -e "$violations" >&2
    exit 2
fi

exit 0
