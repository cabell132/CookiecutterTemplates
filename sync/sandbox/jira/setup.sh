#!/usr/bin/env bash
# setup.sh - One-time AFK pipeline setup
#
# Builds Docker image, creates sandbox, verifies Claude + Bun work inside.
#
# Usage:
#   bash .claude/sandbox/setup.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

IMAGE="claude-__PROJECT_SLUG__:v1"

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}   AFK Pipeline Setup                      ${NC}"
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

# Jira env file?
if [[ ! -f "$JIRA_ENV_FILE" ]]; then
    echo -e "${RED}Jira credentials not found at $JIRA_ENV_FILE${NC}"
    echo -e "${RED}Create it with JIRA_URL, JIRA_USERNAME, JIRA_API_TOKEN${NC}"
    exit 1
fi
# Verify required Jira vars
source "$JIRA_ENV_FILE"
for var in JIRA_URL JIRA_USERNAME JIRA_API_TOKEN; do
    if [[ -z "${!var:-}" ]]; then
        echo -e "${RED}Missing $var in $JIRA_ENV_FILE${NC}"
        exit 1
    fi
done
echo -e "  Jira credentials: ${GREEN}found${NC}"

# Jira project config?
if [[ ! -f "$JIRA_PROJECT_FILE" ]]; then
    echo -e "${RED}Jira project config not found at $JIRA_PROJECT_FILE${NC}"
    exit 1
fi
echo -e "  Jira project:     ${GREEN}$(jq -r '.projectKey' "$JIRA_PROJECT_FILE")${NC}"

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

docker sandbox run -t "$IMAGE" claude . -- \
    --print "Setup complete. Reply with only: Sandbox initialized successfully."

echo -e "${GREEN}Sandbox created.${NC}"
echo ""

# ── Verify Bun ─────────────────────────────────────────────────────────────

echo -e "${CYAN}Verifying Bun inside sandbox...${NC}"
bun_version=$(docker sandbox exec "$SANDBOX_NAME" -- bun --version 2>/dev/null || echo "FAILED")
if [[ "$bun_version" == "FAILED" ]]; then
    echo -e "${RED}Bun verification failed inside sandbox.${NC}"
    exit 1
fi
echo -e "  Bun version: ${GREEN}$bun_version${NC}"
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
echo -e "  Bun:      ${CYAN}$bun_version${NC}"
echo -e "  State:    ${CYAN}$AFK_DIR${NC}"
echo ""
echo -e "${GRAY}Next: bash .claude/sandbox/afk.sh --dry-run${NC}"
echo ""
