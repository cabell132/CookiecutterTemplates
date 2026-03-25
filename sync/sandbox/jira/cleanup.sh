#!/usr/bin/env bash
# cleanup.sh - Remove AFK sandbox and optionally purge state
#
# Usage:
#   bash .claude/sandbox/cleanup.sh           # Remove sandbox only
#   bash .claude/sandbox/cleanup.sh --purge   # Remove sandbox + .afk/ state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

echo -e "${CYAN}AFK Pipeline Cleanup${NC}"
echo ""

# Remove sandbox
if docker sandbox ls 2>/dev/null | grep -q "$SANDBOX_NAME"; then
    echo -e "Removing sandbox: ${YELLOW}$SANDBOX_NAME${NC}"
    docker sandbox rm "$SANDBOX_NAME" 2>/dev/null
    echo -e "${GREEN}Sandbox removed.${NC}"
else
    echo -e "${GRAY}Sandbox '$SANDBOX_NAME' not found (already removed).${NC}"
fi

# Optionally purge state
if [[ "${1:-}" == "--purge" ]]; then
    if [[ -d "$AFK_DIR" ]]; then
        echo -e "Purging state: ${YELLOW}$AFK_DIR${NC}"
        rm -rf "$AFK_DIR"
        echo -e "${GREEN}State purged.${NC}"
    else
        echo -e "${GRAY}State directory not found (already clean).${NC}"
    fi
fi

echo ""
echo -e "${GREEN}Cleanup complete.${NC}"
