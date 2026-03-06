#!/usr/bin/env bash
# Auto-run Vitest when test files are edited
FILE=$(jq -r '.tool_input.file_path' <<< "$(cat)")
if [[ "$FILE" == *.test.* || "$FILE" == *.spec.* ]]; then
  {% if cookiecutter.node_package_manager == "bun" %}bunx{% elif cookiecutter.node_package_manager == "pnpm" %}pnpm exec{% else %}npx{% endif %} vitest run "$FILE" 2>&1 | tail -5
fi
exit 0
