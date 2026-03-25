#!/usr/bin/env bash
# setup.sh - One-time sandbox setup
#
# Builds Docker image, creates sandbox, verifies Claude + tooling work inside.
#
# Usage:
#   bash .claude/sandbox/setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

IMAGE="claude-__PROJECT_SLUG__:v1"

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   Sandbox Setup                           ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""

# ── Prerequisite checks ───────────────────────────────────────────────────

echo -e "${GRAY}Checking prerequisites...${NC}"

# Docker installed?
if ! command -v docker &>/dev/null; then
    echo -e "${RED}Docker not found. Install Docker Desktop 4.40+.${NC}"
    exit 1
fi
echo -e "  Docker:          ${GREEN}$(docker --version | head -1)${NC}"

# Docker sandbox feature available?
if ! docker sandbox ls &>/dev/null; then
    echo -e "${RED}Docker sandbox not available. Requires Docker Desktop 4.40+.${NC}"
    echo -e "${RED}Enable it in Docker Desktop settings or update Docker.${NC}"
    exit 1
fi
echo -e "  Sandbox support: ${GREEN}available${NC}"

# Refresh OAuth token from ~/.claude/.credentials.json into .env
refresh_oauth_token || exit 1

# Verify GH_TOKEN in .env
ENV_FILE="$REPO_ROOT/.env"
gh_token=$(grep "^GH_TOKEN=" "$ENV_FILE" 2>/dev/null | cut -d= -f2-)
if [[ -z "$gh_token" ]]; then
    echo -e "${RED}Missing GH_TOKEN in $ENV_FILE${NC}"
    echo -e "${RED}Add: GH_TOKEN=<your-github-token>${NC}"
    exit 1
fi
echo -e "  Auth tokens:      ${GREEN}CLAUDE_CODE_OAUTH_TOKEN (auto) + GH_TOKEN set${NC}"

# jq on host?
if ! command -v jq &>/dev/null && ! command -v jq.exe &>/dev/null; then
    echo -e "${RED}jq not found on PATH. Install jq for JSON parsing.${NC}"
    exit 1
fi
echo -e "  jq:               ${GREEN}found${NC}"

echo ""

# ── Build image ────────────────────────────────────────────────────────────

echo -e "${CYAN}Building Docker image: $IMAGE${NC}"
docker build -t "$IMAGE" "$SCRIPT_DIR/"
echo -e "${GREEN}Image built successfully.${NC}"
echo ""

# ── Create sandbox ─────────────────────────────────────────────────────────

echo -e "${CYAN}Creating sandbox: $SANDBOX_NAME${NC}"

# Remove existing sandbox if present
if docker sandbox ls 2>/dev/null | grep -q "$SANDBOX_NAME"; then
    echo -e "${YELLOW}Removing existing sandbox...${NC}"
    docker sandbox rm "$SANDBOX_NAME" 2>/dev/null || true
fi

# Create sandbox (run initializes it with a trivial prompt)
docker sandbox run -t "$IMAGE" claude . -- \
    --print "Say OK" 2>/dev/null || true

echo -e "${GREEN}Sandbox created.${NC}"
echo ""

# ── Verify tools inside sandbox ────────────────────────────────────────────

echo -e "${CYAN}Verifying tools inside sandbox...${NC}"

# PROJECT-SPECIFIC: customize verification for your runtime (uv, node, bun, etc.)
runtime_version=$(MSYS_NO_PATHCONV=1 docker sandbox exec "$SANDBOX_NAME" bash -c '__RUNTIME__ --version' 2>/dev/null || echo "FAILED")
if [[ "$runtime_version" == "FAILED" ]]; then
    echo -e "${RED}Runtime verification failed inside sandbox.${NC}"
    exit 1
fi
echo -e "  Runtime: ${GREEN}$runtime_version${NC}"

claude_test=$(sandbox_claude "--print 'Reply with only: OK'" 2>/dev/null || echo "FAILED")
if [[ "$claude_test" == *"OK"* ]]; then
    echo -e "  Claude: ${GREEN}responding${NC}"
else
    echo -e "${RED}Claude verification failed inside sandbox.${NC}"
    echo -e "${GRAY}Output: $claude_test${NC}"
    exit 1
fi
echo ""

# ── Create state directory ─────────────────────────────────────────────────

mkdir -p "$AFK_DIR"

# ── Summary ────────────────────────────────────────────────────────────────

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}   Setup Complete                          ${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "  Sandbox:  ${CYAN}$SANDBOX_NAME${NC}"
echo -e "  Image:    ${CYAN}$IMAGE${NC}"
echo -e "  Runtime:  ${CYAN}$runtime_version${NC}"
echo -e "  State:    ${CYAN}$AFK_DIR${NC}"
echo ""
echo -e "${GRAY}Next: bash .claude/sandbox/once.sh${NC}"
echo ""
