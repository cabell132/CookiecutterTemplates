#!/usr/bin/env bash
# Block edits to sensitive/generated files
FILE=$(jq -r '.tool_input.file_path' <<< "$(cat)")
PROTECTED=(".env" "secrets/" "package-lock.json" "pnpm-lock.yaml" "bun.lockb")
for p in "${PROTECTED[@]}"; do
  if [[ "$FILE" == *"$p"* ]]; then
    echo "Protected file: $p" >&2
    exit 2
  fi
done
exit 0
