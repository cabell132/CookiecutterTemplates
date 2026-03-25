#!/usr/bin/env bash
# once.sh - AFK loop with streaming output
#
# Queries GitHub for labelled issues, implements each inside a Docker
# sandbox, commits locally. Queue issues, run this, walk away.
#
# Usage:
#   bash .claude/sandbox/once.sh                       # Process up to 5 issues
#   bash .claude/sandbox/once.sh --max-issues 1        # Single issue
#   bash .claude/sandbox/once.sh --dry-run             # List issues without executing
#   bash .claude/sandbox/once.sh --verbose             # Detailed output
#   bash .claude/sandbox/once.sh --reset               # Clear .afk/ state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── Defaults ───────────────────────────────────────────────────────────────

MAX_ISSUES=5
DRY_RUN=false
RESET=false
VERBOSE=false

# ── Argument parsing ──────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-issues)  MAX_ISSUES="$2"; shift 2 ;;
        --dry-run)     DRY_RUN=true; shift ;;
        --reset)       RESET=true; shift ;;
        --verbose)     VERBOSE=true; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

export VERBOSE

# ── Banner ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}GitHub issue automation in Docker sandboxes${NC}"
echo ""

# ── Reset ──────────────────────────────────────────────────────────────────

if [[ "$RESET" == "true" ]]; then
    if [[ -d "$AFK_DIR" ]]; then
        rm -rf "$AFK_DIR"
        echo -e "${YELLOW}Reset: Cleared .afk/ directory${NC}"
    fi
fi

# ── Prerequisites ──────────────────────────────────────────────────────────

if ! command -v jq &>/dev/null && ! command -v jq.exe &>/dev/null; then
    echo -e "${RED}jq not found on PATH.${NC}"
    exit 1
fi

if [[ "$DRY_RUN" != "true" ]]; then
    require_sandbox
fi

# ── State setup ────────────────────────────────────────────────────────────

mkdir -p "$AFK_DIR"
touch "$ACTIVITY_LOG"

write_log "Run started (max_issues=$MAX_ISSUES, dry_run=$DRY_RUN)"

echo -e "Max issues:  ${CYAN}$MAX_ISSUES${NC}"
echo -e "Dry run:     ${CYAN}$DRY_RUN${NC}"
echo ""

# ── Counters ───────────────────────────────────────────────────────────────

issues_done=0
issues_failed=0

# ── Main loop ──────────────────────────────────────────────────────────────

for (( i=1; i<=MAX_ISSUES; i++ )); do
    echo -e "${CYAN}── Iteration $i/$MAX_ISSUES ──${NC}"

    # Fetch open labelled issues each iteration
    ISSUES="$(gh issue list \
        --state open \
        --label __ISSUE_LABEL__ \
        --json number,title,body,comments \
        --limit 50 2>/dev/null || echo '[]')"

    total=$(echo "$ISSUES" | jq 'length')

    if [[ "$total" -eq 0 ]]; then
        echo -e "${GREEN}No open labelled issues remaining. All done!${NC}"
        write_log "No open labelled issues remaining."
        break
    fi

    # Log fetched issues
    issue_nums=$(echo "$ISSUES" | jq -r '[.[].number] | map("#" + tostring) | join(", ")')
    write_log "Fetched $total issues: $issue_nums"
    echo -e "${GRAY}Found $total issues: $issue_nums${NC}"

    # Pick first issue (already priority-ordered by GitHub)
    issue=$(echo "$ISSUES" | jq '.[0]')
    issue_num=$(echo "$issue" | jq -r '.number')
    issue_title=$(echo "$issue" | jq -r '.title')

    echo ""
    echo -e "${CYAN}Top issue:  #$issue_num${NC}"
    echo -e "${GRAY}Title:      $issue_title${NC}"
    echo -e "${GRAY}(Claude may choose a different unblocked issue)${NC}"

    # Dry run: just list, don't execute
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${GRAY}  [DRY RUN] Would process: #$issue_num - $issue_title${NC}"
        write_log "DRY RUN: would process #$issue_num"
        (( issues_done++ )) || true
        continue
    fi

    # Snapshot HEAD before sandbox runs so we can detect new commits
    pre_head=$(cd "$REPO_ROOT" && git rev-parse HEAD 2>/dev/null || echo "")

    write_log "START #$issue_num: $issue_title" "START"
    echo -e "${CYAN}Starting sandbox execution...${NC}"

    # Refresh OAuth token from credentials file before each run
    refresh_oauth_token || { write_log "Token refresh failed" "ERROR"; break; }

    # Fetch recent AFK commits for context
    COMMITS="$(cd "$REPO_ROOT" && git log --grep='AFK' -n 10 --oneline 2>/dev/null || echo '(none)')"

    # Build prompt from template
    PROMPT="$(cat "$PROMPT_FILE")"
    FULL_PROMPT="$(cat <<PROMPT_EOF
$PROMPT

---

## Open Issues (JSON)

\`\`\`json
$ISSUES
\`\`\`

## Recent AFK Commits

\`\`\`
$COMMITS
\`\`\`
PROMPT_EOF
)"

    # Run Claude in sandbox via exec (docker sandbox run swallows stdout on Windows)
    stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'
    sandbox_exit=0
    sandbox_tmpfile=$(mktemp)

    # Write prompt to temp file in workspace (avoids shell quoting issues with docker exec)
    prompt_tmpfile="$REPO_ROOT/.afk/prompt-$$.md"
    echo "$FULL_PROMPT" > "$prompt_tmpfile"

    # stream-json + grep filters to valid JSON, tee saves for post-check, jq streams text
    MSYS_NO_PATHCONV=1 docker sandbox exec "$SANDBOX_NAME" \
        bash -c "cd '$SANDBOX_REPO_ROOT' && /usr/local/bin/claude --print --verbose --output-format stream-json \"\$(cat .afk/prompt-$$.md)\"" \
    2>/dev/null \
    | grep --line-buffered '^{' \
    | tee "$sandbox_tmpfile" \
    | jq --unbuffered -rj "$stream_text" \
    || sandbox_exit=$?

    rm -f "$prompt_tmpfile"

    # Check sandbox result
    if grep -q '"type":"result"' "$sandbox_tmpfile" 2>/dev/null; then
        write_log "Sandbox completed for #$issue_num"
    else
        write_log "Sandbox exited without result for #$issue_num (exit=$sandbox_exit)" "WARN"
    fi

    # Check for completion sigil
    if grep -q 'COMPLETE' "$sandbox_tmpfile" 2>/dev/null; then
        echo ""
        echo -e "${GREEN}All tasks complete. Exiting.${NC}"
        rm -f "$sandbox_tmpfile"
        break
    fi

    rm -f "$sandbox_tmpfile"

    # Check outcome: did the agent commit anything since pre_head?
    new_commits=$(cd "$REPO_ROOT" && git log --oneline "$pre_head"..HEAD 2>/dev/null || echo "")
    afk_commit=$(echo "$new_commits" | grep 'AFK' | head -1)

    if [[ -n "$afk_commit" ]]; then
        # Extract the actual issue number from the commit message
        done_num=$(echo "$afk_commit" | grep -oE '#[0-9]+' | head -1 | tr -d '#')
        done_num=${done_num:-$issue_num}
        echo -e "${GREEN}DONE #$done_num: $afk_commit${NC}"
        write_log "DONE #$done_num: $afk_commit"
        (( issues_done++ )) || true

        # Close the issue on GitHub if still open
        if [[ -n "$done_num" ]]; then
            issue_state=$(gh issue view "$done_num" --json state -q '.state' 2>/dev/null || echo "")
            if [[ "$issue_state" == "OPEN" ]]; then
                gh issue close "$done_num" --comment "Closed by AFK agent — $afk_commit" 2>/dev/null \
                    && echo -e "${GREEN}Closed #$done_num on GitHub${NC}" \
                    || echo -e "${YELLOW}Warning: failed to close #$done_num${NC}"
                write_log "Closed #$done_num on GitHub"
            fi
        fi
    else
        echo -e "${RED}FAIL: no AFK commit found (sandbox exit $sandbox_exit)${NC}"
        write_log "FAIL: no AFK commit after processing (exit=$sandbox_exit)" "FAIL"
        (( issues_failed++ )) || true
    fi

    echo ""
done

# ── Summary ────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}         AFK RUN SUMMARY                   ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "  Done:    ${GREEN}$issues_done${NC}"
echo -e "  Failed:  ${RED}$issues_failed${NC}"
echo ""
echo -e "${GRAY}Activity log: $ACTIVITY_LOG${NC}"

write_log "Run complete: $issues_done done, $issues_failed failed"

echo ""
