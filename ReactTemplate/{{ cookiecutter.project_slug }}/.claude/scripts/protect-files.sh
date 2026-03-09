#!/usr/bin/env bash
# Block edits to sensitive/generated files and template-managed config
input=$(cat)
FILE=$(echo "$input" | jq -r '.tool_input.file_path // empty')

[ -z "$FILE" ] && exit 0

# Sensitive/generated files
PROTECTED=(".env" "secrets/" "package-lock.json" "pnpm-lock.yaml" "bun.lockb")
for p in "${PROTECTED[@]}"; do
  if [[ "$FILE" == *"$p"* ]]; then
    echo "Protected file: $p" >&2
    exit 2
  fi
done

# Template-managed config files
TEMPLATE_MANAGED=(
    "biome.json"
    "eslint.jsdoc.cjs"
    "tsconfig.json"
    "tsconfig.app.json"
    "tsconfig.node.json"
    "vite.config.ts"
    "vitest.config.ts"
    ".claude/settings.json"
    ".claude/scripts/"
    ".claude/agents/"
)
for pattern in "${TEMPLATE_MANAGED[@]}"; do
    if [[ "$FILE" == *"$pattern"* ]]; then
        echo "BLOCKED: $FILE is managed by the cookiecutter template." >&2
        echo "Do not edit config files to suppress linting errors — fix the code instead." >&2
        echo "To update template files, use /sync-cookiecutter-template." >&2
        exit 2
    fi
done

exit 0
