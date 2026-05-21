#!/bin/bash
# Stop hook: Block Python files exceeding 300 code lines
# Code lines = total minus docstrings, comments, and blank lines
# Hard cap: 500 total lines regardless

modified_files=$(git diff --name-only --diff-filter=ACM HEAD -- '*.py' 2>/dev/null)
untracked_files=$(git ls-files --others --exclude-standard -- '*.py' 2>/dev/null)
all_files=$(echo -e "${modified_files}\n${untracked_files}" | grep -v '^$' | sort -u)

[ -z "$all_files" ] && exit 0

violations=""
for file_path in $all_files; do
    [ ! -f "$file_path" ] && continue

    # Skip files inside models/ directories (many small model modules expected)
    [[ "$file_path" == */models/* ]] && continue

    total_lines=$(wc -l < "$file_path")

    # Hard cap on total lines
    if [ "$total_lines" -gt 500 ]; then
        violations="${violations}${file_path}: ${total_lines} total lines (hard cap 500)\n"
        continue
    fi

    # Count code-only lines (exclude docstrings, comments, blanks) using Python ast
    code_lines=$(python3 -c "
import ast, sys

try:
    with open(sys.argv[1]) as f:
        source = f.read()
        lines = source.splitlines()
    total = len(lines)

    # Find docstring line ranges via AST
    tree = ast.parse(source)
    docstring_lines = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.Module, ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            if (node.body and isinstance(node.body[0], ast.Expr)
                    and isinstance(node.body[0].value, (ast.Constant, ast.Str))):
                ds = node.body[0]
                for ln in range(ds.lineno, ds.end_lineno + 1):
                    docstring_lines.add(ln)

    # Count non-docstring, non-comment, non-blank lines
    code = 0
    for i, line in enumerate(lines, 1):
        stripped = line.strip()
        if i in docstring_lines:
            continue
        if not stripped or stripped.startswith('#'):
            continue
        code += 1
    print(code)
except Exception:
    # If parsing fails, fall back to total
    print(total)
" "$file_path")

    if [ "$code_lines" -gt 300 ]; then
        violations="${violations}${file_path}: ${code_lines} code lines (${total_lines} total)\n"
    fi
done

if [ -n "$violations" ]; then
    echo "=== File Length Violations ===" >&2
    echo -e "$violations" >&2
    echo "Split into smaller modules." >&2
    exit 2
fi

exit 0
