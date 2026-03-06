#!/usr/bin/env bash
# Auto-format + lint fix with Biome on TS/JS files after edits
FILE=$(jq -r '.tool_input.file_path' <<< "$(cat)")
if [[ "$FILE" == *.ts || "$FILE" == *.tsx || "$FILE" == *.js || "$FILE" == *.jsx ]]; then
  {% if cookiecutter.node_package_manager == "bun" %}bunx{% elif cookiecutter.node_package_manager == "pnpm" %}pnpm exec{% else %}npx{% endif %} biome check --write "$FILE" 2>/dev/null
fi
exit 0
