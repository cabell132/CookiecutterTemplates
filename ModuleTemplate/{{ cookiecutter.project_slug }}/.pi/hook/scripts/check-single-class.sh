#!/bin/bash
# Stop hook: Block multiple classes per file (>50 lines each)

modified_files=$(git diff --name-only --diff-filter=ACM HEAD -- '*.py' 2>/dev/null)
untracked_files=$(git ls-files --others --exclude-standard -- '*.py' 2>/dev/null)
all_files=$(echo -e "${modified_files}\n${untracked_files}" | grep -v '^$' | sort -u)

[ -z "$all_files" ] && exit 0

violations=""
for file_path in $all_files; do
    [ ! -f "$file_path" ] && continue
    # Skip test files — class-based test grouping is normal
    [[ "$file_path" == tests/* || "$file_path" == */tests/* ]] && continue

    # Skip Pydantic model files — multiple small classes per file is normal
    # Handle both Unix (/) and Windows (\) path separators
    [[ "$file_path" == */models/* || "$file_path" == *\\models\\* || "$file_path" == */models.py || "$file_path" == *\\models.py ]] && continue

    class_count=$(grep -c '^class ' "$file_path" 2>/dev/null || echo 0)
    line_count=$(wc -l < "$file_path")

    if [ "$class_count" -gt 1 ] && [ "$line_count" -gt 50 ]; then
        violations="${violations}${file_path}: ${class_count} classes, ${line_count} lines\n"
    fi
done

if [ -n "$violations" ]; then
    echo "=== Single Class Per File Violations ===" >&2
    echo -e "$violations" >&2
    echo "Extract each class > 50 lines to its own module." >&2
    exit 2
fi

exit 0
