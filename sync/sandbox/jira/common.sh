#!/usr/bin/env bash
# common.sh - Shared utilities for AFK pipeline
#
# Sourced by all sandbox scripts. Provides Jira query, sandbox helpers,
# ADF extraction, dependency checking, and logging.

# ── Constants ──────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
REPO_NAME="$(basename "$REPO_ROOT")"
SANDBOX_NAME="claude-$REPO_NAME"
AFK_DIR="$REPO_ROOT/.afk"
REVIEWS_DIR="$AFK_DIR/reviews"
ACTIVITY_LOG="$AFK_DIR/activity.log"
PROMPT_FILE="$SCRIPT_DIR/prompt.md"
JIRA_ENV_FILE="$HOME/.env.jira"
JIRA_PROJECT_FILE="$REPO_ROOT/.jira-project.json"

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

# ── Jira helpers ───────────────────────────────────────────────────────────

# Acceptance criteria custom field ID from project config
AC_FIELD=$(jq -r '.customFields.acceptanceCriteria' "$JIRA_PROJECT_FILE" 2>/dev/null)

jira_search() {
    local jql="$1"
    local fields="${2:-summary,status,labels,issuetype,priority}"
    source "$JIRA_ENV_FILE"
    local base_url="${JIRA_URL%/}"
    curl -sf -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        "$base_url/rest/api/3/search/jql" \
        -G --data-urlencode "jql=$jql" \
        --data-urlencode "fields=$fields" \
        --data-urlencode "maxResults=50" \
        -H "Accept: application/json"
}

# Recursively extract text nodes from Atlassian Document Format JSON
adf_to_text() {
    echo "$1" | jq -r '
        def walk_text:
            if type == "object" then
                if .type == "text" then .text // ""
                elif .type == "hardBreak" then "\n"
                elif .type == "listItem" then "- " + ([.content[]? | walk_text] | join(""))
                elif .type == "heading" then "\n" + ([.content[]? | walk_text] | join("")) + "\n"
                else [.content[]? | walk_text] | join("")
                end
            elif type == "array" then [.[] | walk_text] | join("")
            else ""
            end;
        walk_text
    ' 2>/dev/null
}

# ── WIP check ──────────────────────────────────────────────────────────────

get_wip_count() {
    local result
    result=$(jira_search "project = __PROJECT_KEY__ AND status = 'In Progress'" "summary")
    echo "$result" | jq '[.issues // [] | length] | .[0]'
}

# ── Dependency check (Jira issue links) ───────────────────────────────────

# Fetch issue links for a story, return "blocked" keys that aren't Done
get_unresolved_blockers() {
    local story_key="$1"
    source "$JIRA_ENV_FILE"
    local base_url="${JIRA_URL%/}"

    local issue_json
    issue_json=$(curl -sf -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        "$base_url/rest/api/3/issue/$story_key?fields=issuelinks" \
        -H "Accept: application/json")

    [[ -z "$issue_json" ]] && return 0

    # Jira link direction (confirmed empirically):
    #   - inwardIssue = the blocker (performs the action)
    #   - outwardIssue = the blocked issue (receives the action)
    # When fetching WH-131 (the blocked story), its issuelinks array contains
    # links where inwardIssue = WH-130 (the blocker).
    # type.inward = "is blocked by" appears on the inwardIssue side.
    echo "$issue_json" | jq -r '
        .fields.issuelinks // []
        | map(
            select(
                .type.inward == "is blocked by"
                and .inwardIssue != null
                and .inwardIssue.fields.status.name != "Done"
            )
            | .inwardIssue.key
        )
        | .[]
    ' 2>/dev/null
}

# Check if a story is safe to start (no unresolved blockers)
is_story_unblocked() {
    local story_key="$1"
    local blockers
    blockers=$(get_unresolved_blockers "$story_key")
    if [[ -n "$blockers" ]]; then
        echo "$blockers"
        return 1
    fi
    return 0
}

# ── Jira issue creation ───────────────────────────────────────────────────

# Create a Jira issue. Returns the new issue key.
# Args: summary, description, issue_type_id, labels_json, link_key
# Note: link_key creates a "Relates" link (not parent — Tasks/Bugs can't be children of Stories)
jira_create_issue() {
    local summary="$1"
    local description="$2"
    local issue_type_id="$3"
    local labels_json="$4"
    local link_key="$5"
    local project_key
    project_key=$(jq -r '.projectKey' "$JIRA_PROJECT_FILE")
    source "$JIRA_ENV_FILE"
    local base_url="${JIRA_URL%/}"

    # Truncate description to 32000 chars (Jira ADF text node limit)
    if [[ ${#description} -gt 32000 ]]; then
        description="${description:0:32000}..."
    fi

    # Convert plain text to ADF: split on newlines into paragraphs,
    # treat "---" lines as horizontal rules, empty lines as breaks
    local adf_content
    adf_content=$(echo "$description" | jq -Rs '
        split("\n")
        | reduce .[] as $line ([];
            if $line == "---" then
                . + [{"type": "rule"}]
            elif ($line | length) == 0 then
                .
            else
                . + [{"type": "paragraph", "content": [{"type": "text", "text": $line}]}]
            end
        )
    ')

    local payload_file
    payload_file=$(mktemp)
    jq -n \
        --arg project_key "$project_key" \
        --arg summary "$summary" \
        --arg issue_type_id "$issue_type_id" \
        --argjson labels "$labels_json" \
        --argjson adf_content "$adf_content" \
        '{
            fields: {
                project: { key: $project_key },
                summary: $summary,
                description: {
                    type: "doc",
                    version: 1,
                    content: $adf_content
                },
                issuetype: { id: $issue_type_id },
                labels: $labels
            }
        }' > "$payload_file"

    local response http_code
    response=$(curl -s -w "\n%{http_code}" -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        "$base_url/rest/api/3/issue" \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d @"$payload_file")
    rm -f "$payload_file"

    http_code=$(echo "$response" | tail -1)
    response=$(echo "$response" | sed '$d')

    if [[ "$http_code" -lt 200 || "$http_code" -ge 300 ]]; then
        local errors
        errors=$(echo "$response" | jq -r '.errors // .errorMessages // empty' 2>/dev/null)
        echo "ERROR: Jira create failed (HTTP $http_code): $errors" >&2
        return 1
    fi

    local new_key
    new_key=$(echo "$response" | jq -r '.key')

    # Create "Relates" link to the story if link_key provided
    if [[ -n "$link_key" ]]; then
        jira_create_link "$new_key" "$link_key" || true
    fi

    echo "$new_key"
}

# Create a "Relates" issue link between two Jira issues
# Args: from_key, to_key
jira_create_link() {
    local from_key="$1"
    local to_key="$2"
    source "$JIRA_ENV_FILE"
    local base_url="${JIRA_URL%/}"

    curl -sf -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        "$base_url/rest/api/3/issueLink" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"type\":{\"name\":\"Relates\"},\"inwardIssue\":{\"key\":\"$from_key\"},\"outwardIssue\":{\"key\":\"$to_key\"}}" \
        >/dev/null
}

# Transition a Jira issue to a target status by name
# Args: issue_key, target_status_name
jira_transition_to() {
    local issue_key="$1"
    local target_status="$2"
    source "$JIRA_ENV_FILE"
    local base_url="${JIRA_URL%/}"

    # Get available transitions
    local transitions
    transitions=$(curl -sf -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        "$base_url/rest/api/3/issue/$issue_key/transitions" \
        -H "Accept: application/json")

    # Find the transition ID for the target status
    local transition_id
    transition_id=$(echo "$transitions" | jq -r \
        --arg target "$target_status" \
        '.transitions[] | select(.name == $target or .to.name == $target) | .id' \
        | head -1)

    if [[ -z "$transition_id" ]]; then
        echo "WARN: No transition found to '$target_status' for $issue_key" >&2
        return 1
    fi

    curl -sf -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        "$base_url/rest/api/3/issue/$issue_key/transitions" \
        -X POST \
        -H "Content-Type: application/json" \
        -d "{\"transition\":{\"id\":\"$transition_id\"}}" \
        >/dev/null
}

# Look up related story key from a Jira issue (via "Relates" link)
# Args: issue_key
get_parent_story_key() {
    local issue_key="$1"
    source "$JIRA_ENV_FILE"
    local base_url="${JIRA_URL%/}"

    local issue_json
    issue_json=$(curl -sf -u "$JIRA_USERNAME:$JIRA_API_TOKEN" \
        "$base_url/rest/api/3/issue/$issue_key?fields=issuelinks" \
        -H "Accept: application/json")

    # Find the first "Relates" outward issue (the linked story)
    echo "$issue_json" | jq -r '
        .fields.issuelinks // []
        | map(select(.type.name == "Relates"))
        | first
        | (.outwardIssue.key // .inwardIssue.key // empty)
    '
}

# Find remote branch matching a story key pattern
# Args: story_key
find_branch_for_story() {
    local story_key="$1"

    git fetch --prune origin 2>/dev/null || true

    # Match origin/*/<KEY>-* (e.g., origin/feature/WH-101-some-slug)
    local branch
    branch=$(git branch -r --list "origin/*/${story_key}-*" 2>/dev/null | head -1 | xargs)

    if [[ -z "$branch" ]]; then
        return 1
    fi

    # Strip origin/ prefix
    echo "${branch#origin/}"
}

# ── Sandbox helpers ────────────────────────────────────────────────────────

require_sandbox() {
    if ! docker sandbox ls 2>/dev/null | grep -q "$SANDBOX_NAME"; then
        echo -e "${RED}Sandbox '$SANDBOX_NAME' not found. Run: bash .claude/sandbox/setup.sh${NC}"
        exit 1
    fi
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
    echo "$entry" >> "$ACTIVITY_LOG"
    if [[ "${VERBOSE:-false}" == "true" ]] || [[ "$level" == "ERROR" ]]; then
        echo "$entry"
    fi
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
