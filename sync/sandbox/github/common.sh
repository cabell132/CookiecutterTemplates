#!/usr/bin/env bash
# common.sh - Shared utilities for sandbox scripts
#
# Sourced by all sandbox scripts. Provides sandbox helpers,
# dependency checking, logging, and cross-platform shims.

# ── Constants ──────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
REPO_NAME="$(basename "$REPO_ROOT")"
SANDBOX_NAME="claude-${REPO_NAME}"
AFK_DIR="$REPO_ROOT/.afk"
ACTIVITY_LOG="$AFK_DIR/activity.log"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"

# Docker sandbox mounts Windows paths as /c/Users/... not C:/Users/...
# Convert for use with docker sandbox exec
SANDBOX_REPO_ROOT="$(echo "$REPO_ROOT" | sed 's|^\([A-Z]\):|/\L\1|')"

# ── Cross-platform shims ──────────────────────────────────────────────────

# Wrap jq to strip \r — Windows jq.exe emits CRLF which breaks bash arithmetic
if [[ "$(uname -o 2>/dev/null || true)" == "Msys" ]] || [[ "$(uname -s)" == *MINGW* ]] || [[ "$(uname -s)" == *CYGWIN* ]] || [[ -n "${WSLENV:-}" ]]; then
    _JQ_BIN="$(command -v jq 2>/dev/null || command -v jq.exe 2>/dev/null)"
    jq() { "$_JQ_BIN" "$@" | tr -d '\r'; }
fi

# Color detection
if [[ -t 1 ]]; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'
    CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; GRAY='\033[0;90m'; NC='\033[0m'
else
    RED=""; GREEN=""; YELLOW=""; CYAN=""; MAGENTA=""; GRAY=""; NC=""
fi

# ── Sandbox helpers ────────────────────────────────────────────────────────

require_sandbox() {
    if ! docker sandbox ls 2>/dev/null | grep -q "$SANDBOX_NAME"; then
        echo -e "${RED}Sandbox '$SANDBOX_NAME' not found. Run: bash .claude/sandbox/setup.sh${NC}"
        exit 1
    fi
}

# Run claude inside the sandbox via exec (docker sandbox run swallows stdout on Windows).
# Uses MSYS_NO_PATHCONV to prevent Git Bash from mangling Linux paths.
# Usage: sandbox_claude [claude-args...]
sandbox_claude() {
    MSYS_NO_PATHCONV=1 docker sandbox exec "$SANDBOX_NAME" \
        bash -c "cd '$SANDBOX_REPO_ROOT' && /usr/local/bin/claude $*"
}

# ── Docker user detection ─────────────────────────────────────────────────

get_docker_user() {
    local creds_store
    creds_store=$(jq -r '.credsStore // empty' ~/.docker/config.json 2>/dev/null)
    if [ -n "$creds_store" ] && command -v "docker-credential-$creds_store" >/dev/null 2>&1; then
        echo "https://index.docker.io/v1/" | "docker-credential-$creds_store" get 2>/dev/null | jq -r '.Username // empty'
        return
    fi
    docker info 2>/dev/null | awk '/Username:/ {print $2}'
}

# ── OAuth token refresh ────────────────────────────────────────────────────

CLAUDE_CREDENTIALS="$HOME/.claude/.credentials.json"

# Read the live OAuth token from Claude Code's credentials file and
# write/update it in .env so the sandbox wrapper picks it up.
refresh_oauth_token() {
    local env_file="$REPO_ROOT/.env"

    if [[ ! -f "$CLAUDE_CREDENTIALS" ]]; then
        echo -e "${RED}Claude credentials not found at $CLAUDE_CREDENTIALS${NC}"
        echo -e "${RED}Run 'claude' once to authenticate.${NC}"
        return 1
    fi

    local token
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CLAUDE_CREDENTIALS")
    if [[ -z "$token" ]]; then
        echo -e "${RED}No accessToken in $CLAUDE_CREDENTIALS${NC}"
        return 1
    fi

    # Check expiry (ms epoch)
    local expires_at now_ms
    expires_at=$(jq -r '.claudeAiOauth.expiresAt // 0' "$CLAUDE_CREDENTIALS")
    now_ms=$(($(date +%s) * 1000))
    if [[ "$expires_at" -le "$now_ms" ]]; then
        echo -e "${YELLOW}OAuth token expired. Run 'claude' to refresh, then retry.${NC}"
        return 1
    fi

    # Update or create .env
    if [[ -f "$env_file" ]] && grep -q '^CLAUDE_CODE_OAUTH_TOKEN=' "$env_file"; then
        # Replace existing token line
        local tmp="$env_file.tmp"
        sed "s|^CLAUDE_CODE_OAUTH_TOKEN=.*|CLAUDE_CODE_OAUTH_TOKEN=$token|" "$env_file" > "$tmp"
        mv "$tmp" "$env_file"
    elif [[ -f "$env_file" ]]; then
        echo "CLAUDE_CODE_OAUTH_TOKEN=$token" >> "$env_file"
    else
        echo "CLAUDE_CODE_OAUTH_TOKEN=$token" > "$env_file"
    fi

    echo -e "${GREEN}OAuth token refreshed from credentials file.${NC}"
}

# ── Logging ────────────────────────────────────────────────────────────────

write_log() {
    local msg="$1" level="${2:-INFO}"
    local entry="[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $msg"
    mkdir -p "$AFK_DIR"
    echo "$entry" >> "$ACTIVITY_LOG"
    if [[ "${VERBOSE:-false}" == "true" ]] || [[ "$level" == "ERROR" ]]; then
        echo "$entry"
    fi
}
