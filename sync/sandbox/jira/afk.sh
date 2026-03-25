#!/usr/bin/env bash
# afk.sh - Jira-driven AFK pipeline
#
# Queries Jira for "Ready" stories, implements each inside a Docker sandbox,
# creates branches and PRs automatically. Queue stories, run this, walk away.
#
# Usage:
#   bash .claude/sandbox/afk.sh                        # Process up to 5 stories
#   bash .claude/sandbox/afk.sh --max-stories 1        # Single story
#   bash .claude/sandbox/afk.sh --dry-run              # List stories without executing
#   bash .claude/sandbox/afk.sh --verbose               # Detailed output
#   bash .claude/sandbox/afk.sh --story-timeout 15      # Per-story timeout (minutes)
#   bash .claude/sandbox/afk.sh --skip-review           # Don't run review loop
#   bash .claude/sandbox/afk.sh --reset                 # Clear .afk/ state

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── Defaults ───────────────────────────────────────────────────────────────

MAX_STORIES=100
TIMEOUT_MINUTES=600 # 10 hours
STORY_TIMEOUT_MINUTES=30
DRY_RUN=false
RESET=false
VERBOSE=false
SKIP_REVIEW=false
REVIEW_FIX_PROMPT_FILE="$SCRIPT_DIR/review-fix-prompt.md"

# ── Argument parsing ──────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-stories)  MAX_STORIES="$2"; shift 2 ;;
        --timeout)      TIMEOUT_MINUTES="$2"; shift 2 ;;
        --story-timeout) STORY_TIMEOUT_MINUTES="$2"; shift 2 ;;
        --dry-run)      DRY_RUN=true; shift ;;
        --reset)        RESET=true; shift ;;
        --verbose)      VERBOSE=true; shift ;;
        --skip-review)  SKIP_REVIEW=true; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

export VERBOSE

# ── Banner ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${MAGENTA}     _    _____ _  __  ____  _            _ _            ${NC}"
echo -e "${MAGENTA}    / \\  |  ___| |/ / |  _ \\(_)_ __   ___| (_)_ __   ___${NC}"
echo -e "${MAGENTA}   / _ \\ | |_  | ' /  | |_) | | '_ \\ / _ \\ | | '_ \\ / _ \\${NC}"
echo -e "${MAGENTA}  / ___ \\|  _| | . \\  |  __/| | |_) |  __/ | | | | |  __/${NC}"
echo -e "${MAGENTA} /_/   \\_\\_|   |_|\\_\\ |_|   |_| .__/ \\___|_|_|_| |_|\\___|${NC}"
echo -e "${MAGENTA}                               |_|                       ${NC}"
echo ""
echo -e "${GRAY}Jira-driven story automation in Docker sandboxes${NC}"
echo ""

# ── Reset ──────────────────────────────────────────────────────────────────

if [[ "$RESET" == "true" ]]; then
    if [[ -d "$AFK_DIR" ]]; then
        rm -rf "$AFK_DIR"
        echo -e "${YELLOW}Reset: Cleared .afk/ directory${NC}"
    fi
fi

# ── Prerequisites ──────────────────────────────────────────────────────────

# Verify jq
if ! command -v jq &>/dev/null && ! command -v jq.exe &>/dev/null; then
    echo -e "${RED}jq not found on PATH.${NC}"
    exit 1
fi

# Verify Jira credentials
if [[ ! -f "$JIRA_ENV_FILE" ]]; then
    echo -e "${RED}Jira credentials not found at $JIRA_ENV_FILE${NC}"
    exit 1
fi

# Verify sandbox exists (skip for dry-run)
if [[ "$DRY_RUN" != "true" ]]; then
    require_sandbox
fi

# ── State setup ────────────────────────────────────────────────────────────

mkdir -p "$AFK_DIR"
touch "$ACTIVITY_LOG"

write_log "AFK run started (max_stories=$MAX_STORIES, timeout=${TIMEOUT_MINUTES}m, dry_run=$DRY_RUN)"

echo -e "Max stories:   ${CYAN}$MAX_STORIES${NC}"
echo -e "Timeout:       ${CYAN}${TIMEOUT_MINUTES}m${NC}"
echo -e "Story timeout: ${CYAN}${STORY_TIMEOUT_MINUTES}m${NC}"
echo -e "Dry run:       ${CYAN}$DRY_RUN${NC}"
echo -e "Skip review:   ${CYAN}$SKIP_REVIEW${NC}"
echo ""

# ── Counters ───────────────────────────────────────────────────────────────

stories_done=0
stories_failed=0
stories_skipped=0

# Track processed stories to avoid re-processing (Jira transitions are async)
declare -A processed_keys

# ── Main loop ──────────────────────────────────────────────────────────────

for (( i=1; i<=MAX_STORIES; i++ )); do
    # Always start each iteration on main (previous iteration may leave us on a feature branch)
    git checkout -f main 2>/dev/null
    git clean -fd 2>/dev/null

    echo -e "${CYAN}── Iteration $i/$MAX_STORIES ──${NC}"

    # Re-fetch Ready stories each iteration (see plan for rationale)
    jql="project = __PROJECT_KEY__ AND status = Ready AND type in (Story, Bug, Task) AND labels NOT IN (HITL) ORDER BY rank ASC"
    fields="summary,status,labels,issuetype,priority,description,$AC_FIELD,issuelinks"

    stories_json=$(jira_search "$jql" "$fields")
    total=$(echo "$stories_json" | jq '[.issues // [] | length] | .[0]')

    if [[ "$total" -eq 0 ]]; then
        echo -e "${GREEN}No Ready stories remaining. All done!${NC}"
        write_log "No Ready stories remaining."
        break
    fi

    # Log fetched stories
    story_keys=$(echo "$stories_json" | jq -r '[.issues[].key] | join(", ")')
    write_log "Fetched $total Ready stories: $story_keys"
    echo -e "${GRAY}Found $total Ready stories: $story_keys${NC}"

    # Pick next unblocked story (HITL stories excluded by JQL filter)
    selected_key=""
    selected_index=-1

    for (( j=0; j<total; j++ )); do
        issue=$(echo "$stories_json" | jq ".issues[$j]")
        key=$(echo "$issue" | jq -r '.key')
        labels=$(echo "$issue" | jq -r '[.fields.labels // [] | .[]] | join(",")')

        # Skip already-processed stories (Jira transition may not have propagated yet)
        if [[ -n "${processed_keys[$key]+x}" ]]; then
            echo -e "${GRAY}  SKIP $key: already processed this run${NC}"
            continue
        fi

        # Dependency check
        blockers=""
        blockers=$(is_story_unblocked "$key" 2>/dev/null) || true
        if [[ -n "$blockers" ]]; then
            blocker_list=$(echo "$blockers" | tr '\n' ', ' | sed 's/,$//')
            echo -e "${YELLOW}  SKIP $key: blocked by $blocker_list${NC}"
            write_log "SKIP $key: blocked by $blocker_list" "SKIP"
            (( stories_skipped++ )) || true
            continue
        fi

        selected_key="$key"
        selected_index=$j
        break
    done

    if [[ -z "$selected_key" ]]; then
        echo -e "${YELLOW}All Ready stories are blocked or HITL. Stopping.${NC}"
        write_log "All Ready stories blocked or HITL."
        break
    fi

    # Extract story details
    issue=$(echo "$stories_json" | jq ".issues[$selected_index]")
    summary=$(echo "$issue" | jq -r '.fields.summary // "No summary"')
    story_type=$(echo "$issue" | jq -r '.fields.issuetype.name // "Story"')

    # Extract acceptance criteria (ADF to plain text)
    raw_ac=$(echo "$issue" | jq ".fields.$AC_FIELD")
    if [[ "$raw_ac" == "null" ]] || [[ -z "$raw_ac" ]]; then
        acceptance_criteria="No acceptance criteria provided."
    else
        acceptance_criteria=$(adf_to_text "$raw_ac")
        [[ -z "$acceptance_criteria" ]] && acceptance_criteria="No acceptance criteria provided."
    fi

    # Extract description (ADF to plain text) — used by review-fix prompt
    raw_desc=$(echo "$issue" | jq '.fields.description')
    if [[ "$raw_desc" == "null" ]] || [[ -z "$raw_desc" ]]; then
        description_text="No description provided."
    else
        description_text=$(adf_to_text "$raw_desc")
        [[ -z "$description_text" ]] && description_text="No description provided."
    fi

    echo ""
    echo -e "${CYAN}Story:  $selected_key${NC}"
    echo -e "${GRAY}Title:  $summary${NC}"
    echo -e "${GRAY}Type:   $story_type${NC}"

    # WIP check
    wip_count=$(get_wip_count)
    if [[ "$wip_count" -ge 3 ]]; then
        echo -e "${YELLOW}WIP limit reached ($wip_count in progress). Stopping.${NC}"
        write_log "WIP limit reached: $wip_count in progress." "WARN"
        break
    fi

    # Dry run: just list, don't execute
    if [[ "$DRY_RUN" == "true" ]]; then
        echo -e "${GRAY}  [DRY RUN] Would process: $selected_key - $summary${NC}"
        write_log "DRY RUN: would process $selected_key"
        (( stories_done++ )) || true
        continue
    fi

    write_log "START $selected_key: $summary" "START"
    echo -e "${CYAN}Starting sandbox execution...${NC}"

    # Detect review-fix label for routing
    is_review_fix=false
    if echo "$labels" | grep -qi "review-fix"; then
        is_review_fix=true
    fi

    if [[ "$is_review_fix" == "true" ]]; then
        # ── Review-fix flow: commit to existing feature branch ──
        echo -e "${MAGENTA}  Mode: review-fix (committing to existing branch)${NC}"

        # Find parent story to derive the target branch
        parent_story_key=$(get_parent_story_key "$selected_key" 2>/dev/null || echo "")
        if [[ -z "$parent_story_key" ]]; then
            echo -e "${RED}FAIL $selected_key: no parent story found${NC}"
            write_log "FAIL $selected_key: no parent story for review-fix" "FAIL"
            (( stories_failed++ )) || true
            echo ""
            continue
        fi

        # Find the feature branch for the parent story
        target_branch=$(find_branch_for_story "$parent_story_key" 2>/dev/null || echo "")
        if [[ -z "$target_branch" ]]; then
            echo -e "${RED}FAIL $selected_key: no branch found for parent $parent_story_key${NC}"
            write_log "FAIL $selected_key: no branch for parent $parent_story_key" "FAIL"
            (( stories_failed++ )) || true
            echo ""
            continue
        fi

        # Verify PR is still open
        pr_check=$(gh pr list --head "$target_branch" --json number,state --limit 1 2>/dev/null || echo "[]")
        pr_state=$(echo "$pr_check" | jq -r '.[0].state // "UNKNOWN"')
        pr_number=$(echo "$pr_check" | jq -r '.[0].number // empty')
        if [[ "$pr_state" != "OPEN" ]]; then
            echo -e "${YELLOW}SKIP $selected_key: PR for $target_branch is $pr_state${NC}"
            write_log "SKIP $selected_key: PR is $pr_state" "SKIP"
            (( stories_skipped++ )) || true
            echo ""
            continue
        fi

        # Check concurrency lock
        if [[ -n "$pr_number" ]] && [[ -f "$REVIEWS_DIR/.lock-$pr_number" ]]; then
            lock_time=$(stat -c %Y "$REVIEWS_DIR/.lock-$pr_number" 2>/dev/null || stat -f %m "$REVIEWS_DIR/.lock-$pr_number" 2>/dev/null || echo 0)
            now=$(date +%s)
            lock_age=$(( now - lock_time ))
            if [[ "$lock_age" -lt 3600 ]]; then
                echo -e "${YELLOW}SKIP $selected_key: PR #$pr_number is locked by review-prs.sh${NC}"
                write_log "SKIP $selected_key: PR locked" "SKIP"
                (( stories_skipped++ )) || true
                echo ""
                continue
            fi
        fi

        echo -e "${GRAY}  Parent: $parent_story_key -> Branch: $target_branch${NC}"

        # Build prompt BEFORE checkout (template file won't exist on feature branches)
        prompt_content=$(cat "$REVIEW_FIX_PROMPT_FILE")
        prompt_content="${prompt_content//\{\{STORY_KEY\}\}/$selected_key}"
        prompt_content="${prompt_content//\{\{STORY_SUMMARY\}\}/$summary}"
        prompt_content="${prompt_content//\{\{PARENT_STORY\}\}/$parent_story_key}"
        prompt_content="${prompt_content//\{\{BRANCH_NAME\}\}/$target_branch}"
        prompt_content="${prompt_content//\{\{DESCRIPTION\}\}/$description_text}"
        full_prompt="$prompt_content"

        # Checkout existing branch (already on main from loop start)
        git fetch origin "$target_branch"
        git checkout "$target_branch"
        git pull origin "$target_branch"
    else
        # ── Normal flow: branch from main ──

        # Pull latest main (already checked out at loop start)
        git pull --rebase origin main

        # Build prompt from template
        recent_commits=$(git log --oneline -10)
        prompt_content=$(cat "$PROMPT_FILE")
        # Pure bash substitution handles multi-line strings (sed cannot)
        prompt_content="${prompt_content//\{\{STORY_KEY\}\}/$selected_key}"
        prompt_content="${prompt_content//\{\{STORY_SUMMARY\}\}/$summary}"
        prompt_content="${prompt_content//\{\{STORY_TYPE\}\}/$story_type}"
        prompt_content="${prompt_content//\{\{ACCEPTANCE_CRITERIA\}\}/$acceptance_criteria}"
        prompt_content="${prompt_content//\{\{RECENT_COMMITS\}\}/$recent_commits}"
        full_prompt="$prompt_content"
    fi

    # Refresh OAuth token from credentials file before each run
    refresh_oauth_token || { write_log "Token refresh failed for $selected_key" "ERROR"; (( stories_failed++ )) || true; echo ""; continue; }

    # Run sandbox with stream-json for exit detection (--print alone hangs after completion)
    # Streams both Claude's text output and tool call progress so we can see what's happening
    stream_text='
        if .type == "assistant" then
            .message.content[]? | select(.type == "text") | .text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"
        elif .type == "system" and .subtype == "task_progress" then
            "  \u25b8 " + (.description // .last_tool_name // "") + "\r\n"
        else
            empty
        end
    '
    sandbox_exit=0
    sandbox_tmpfile=$(mktemp)
    signal_file="$(pwd)/.afk-signal"
    story_timeout_seconds=$(( STORY_TIMEOUT_MINUTES * 60 ))

    # Clean up any stale signal file from a previous run
    rm -f "$signal_file"

    # Background monitor: polls for .afk-signal and stops the sandbox when found.
    # Stopping the sandbox breaks the pipe, so the foreground pipeline exits naturally.
    (
        while true; do
            if [[ -f "$signal_file" ]]; then
                signal_content=$(cat "$signal_file" 2>/dev/null || echo "")
                write_log "Detected .afk-signal for $selected_key: $signal_content"
                sleep 15  # grace period for final git push / PR creation
                docker sandbox stop "$SANDBOX_NAME" 2>/dev/null || true
                break
            fi
            sleep 5
        done
    ) &
    monitor_pid=$!

    # Pipeline runs in foreground so streaming output is visible
    sandbox_exit=0
    timeout "${story_timeout_seconds}s" bash -c '
        docker sandbox run "$1" -- \
            --verbose --print --output-format stream-json "$2" \
        2>/dev/null \
        | grep --line-buffered "^{" \
        | tee "$3" \
        | jq --unbuffered -rj "$4"
    ' -- "$SANDBOX_NAME" "$full_prompt" "$sandbox_tmpfile" "$stream_text" \
    || sandbox_exit=$?

    # Clean up monitor
    kill "$monitor_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true

    if [[ "$sandbox_exit" -eq 124 ]] && [[ ! -f "$signal_file" ]]; then
        echo -e "${RED}TIMEOUT $selected_key: exceeded ${STORY_TIMEOUT_MINUTES}m limit${NC}"
        write_log "TIMEOUT $selected_key: killed after ${STORY_TIMEOUT_MINUTES}m" "FAIL"
        (( stories_failed++ )) || true
        rm -f "$sandbox_tmpfile" "$signal_file"
        echo ""
        continue
    elif [[ -f "$signal_file" ]]; then
        signal_content=$(cat "$signal_file" 2>/dev/null || echo "")
        if echo "$signal_content" | grep -qi "^BLOCKED"; then
            echo -e "${YELLOW}BLOCKED $selected_key: $signal_content${NC}"
            write_log "BLOCKED $selected_key: $signal_content" "WARN"
        else
            write_log "Sandbox completed for $selected_key (signal: $signal_content)"
        fi
    elif grep -q '"type":"result"' "$sandbox_tmpfile" 2>/dev/null; then
        write_log "Sandbox completed for $selected_key"
    else
        write_log "Sandbox exited without signal for $selected_key (exit=$sandbox_exit)" "WARN"
    fi
    rm -f "$sandbox_tmpfile" "$signal_file"

    # Restore Windows-compatible node_modules (sandbox installs Linux binaries)
    __INSTALL_COMMAND__ --silent 2>/dev/null || true

    # Check outcome via git/gh (source of truth, not Claude output)
    sleep 2

    if [[ "$is_review_fix" == "true" ]]; then
        # ── Review-fix outcome: verify new commits on existing branch ──
        git fetch origin "$target_branch" 2>/dev/null || true
        latest_sha=$(git rev-parse "origin/$target_branch" 2>/dev/null || echo "")
        pre_sha=$(git rev-parse HEAD 2>/dev/null || echo "")

        if [[ "$latest_sha" != "$pre_sha" ]] || git log --oneline -1 --format="%s" | grep -qi "$selected_key"; then
            echo -e "${GREEN}DONE $selected_key: fix committed to $target_branch${NC}"
            write_log "DONE $selected_key: fix committed to $target_branch"
            jira_transition_to "$selected_key" "Done" 2>/dev/null || true
            (( stories_done++ )) || true
        else
            echo -e "${RED}FAIL $selected_key: no new commits on $target_branch (sandbox exit code $sandbox_exit)${NC}"
            write_log "FAIL $selected_key: no commits on $target_branch (exit=$sandbox_exit)" "FAIL"
            (( stories_failed++ )) || true
        fi
    else
        # ── Normal outcome: look for new branch + PR ──

        # Look for branch
        branch_pattern="origin/*/${selected_key}-*"
        branch_found=$(git branch -r --list "$branch_pattern" 2>/dev/null | head -1 | xargs)

        # Look for PR
        pr_number=""
        if [[ -n "$branch_found" ]]; then
            branch_name="${branch_found#origin/}"
            pr_json=$(gh pr list --head "$branch_name" --json number --limit 1 2>/dev/null || echo "[]")
            pr_number=$(echo "$pr_json" | jq -r '.[0].number // empty')
        fi

        if [[ -n "$pr_number" ]]; then
            echo -e "${GREEN}DONE $selected_key: PR #$pr_number created ($branch_name)${NC}"
            write_log "DONE $selected_key: PR #$pr_number created ($branch_name)"
            (( stories_done++ )) || true
        else
            echo -e "${RED}FAIL $selected_key: no PR created (sandbox exit code $sandbox_exit)${NC}"
            write_log "FAIL $selected_key: no PR created (sandbox exit code $sandbox_exit)" "FAIL"
            (( stories_failed++ )) || true
        fi
    fi

    # Mark as processed so we don't re-pick on next iteration
    processed_keys[$selected_key]=1

    echo ""
done

# ── Summary ────────────────────────────────────────────────────────────────

echo ""
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}         AFK RUN SUMMARY                   ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "  Done:    ${GREEN}$stories_done${NC}"
echo -e "  Failed:  ${RED}$stories_failed${NC}"
echo -e "  Skipped: ${YELLOW}$stories_skipped${NC}"
echo ""
echo -e "${GRAY}Activity log: $ACTIVITY_LOG${NC}"

write_log "AFK run complete: $stories_done done, $stories_failed failed, $stories_skipped skipped"

if [[ "$DRY_RUN" != "true" ]] && [[ "$stories_done" -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Reminder: Run '__INSTALL_COMMAND__' locally to restore platform-compatible dependencies.${NC}"
fi

echo ""
