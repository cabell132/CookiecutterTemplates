#!/usr/bin/env bash
# Block destructive shell command patterns
CMD=$(jq -r '.tool_input.command' <<< "$(cat)")
PATTERNS=("rm -rf /" "rm -rf ~" "drop table" "git push --force" "git push -f ")
for p in "${PATTERNS[@]}"; do
  if echo "$CMD" | grep -qiE "$p"; then
    echo "Blocked: destructive pattern '$p'" >&2
    exit 2
  fi
done
exit 0
