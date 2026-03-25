#!/usr/bin/env bash
# review-prs.sh - Batch PR review pipeline
#
# Discovers open PRs, triages them, runs reviews in Docker sandbox,
# creates Jira fix tickets, and auto-merges clean PRs.
#
# Usage:
#   bash .claude/sandbox/review-prs.sh                          # Review all open PRs
#   bash .claude/sandbox/review-prs.sh --max-prs 3              # Limit to 3 PRs
#   bash .claude/sandbox/review-prs.sh --dry-run                # List PRs without reviewing
#   bash .claude/sandbox/review-prs.sh --triage-only            # Only triage, skip review
#   bash .claude/sandbox/review-prs.sh --re-review-only         # Only re-review previously reviewed PRs
#   bash .claude/sandbox/review-prs.sh --skip-jira              # Skip Jira ticket creation
#   bash .claude/sandbox/review-prs.sh --severity-threshold CRITICAL  # Only create tickets for CRITICAL+
#   bash .claude/sandbox/review-prs.sh --reset                  # Clear review state
#   bash .claude/sandbox/review-prs.sh --verbose                # Detailed output

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# ── Defaults ───────────────────────────────────────────────────────────────

MAX_PRS=100
TIMEOUT_MINUTES=30
MAX_PASSES=3
DRY_RUN=false
TRIAGE_ONLY=false
RE_REVIEW_ONLY=false
SKIP_JIRA=false
RESET=false
VERBOSE=false
SEVERITY_THRESHOLD="IMPORTANT"  # CRITICAL, IMPORTANT, or SUGGESTION

# Issue type IDs from .jira-project.json
TASK_TYPE_ID=$(jq -r '.issueTypes.task.id' "$JIRA_PROJECT_FILE" 2>/dev/null)
BUG_TYPE_ID=$(jq -r '.issueTypes.bug.id' "$JIRA_PROJECT_FILE" 2>/dev/null)

# ── Argument parsing ──────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --max-prs)              MAX_PRS="$2"; shift 2 ;;
        --timeout)              TIMEOUT_MINUTES="$2"; shift 2 ;;
        --max-passes)           MAX_PASSES="$2"; shift 2 ;;
        --dry-run)              DRY_RUN=true; shift ;;
        --triage-only)          TRIAGE_ONLY=true; shift ;;
        --re-review-only)       RE_REVIEW_ONLY=true; shift ;;
        --skip-jira)            SKIP_JIRA=true; shift ;;
        --reset)                RESET=true; shift ;;
        --verbose)              VERBOSE=true; shift ;;
        --severity-threshold)   SEVERITY_THRESHOLD="$2"; shift 2 ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

export VERBOSE

# ── Banner ─────────────────────────────────────────────────────────────────

echo ""
echo -e "${MAGENTA}  ____       _       _       ____            _               ${NC}"
echo -e "${MAGENTA} | __ )  __ _| |_ ___| |__   |  _ \\ _____   _(_) _____      __${NC}"
echo -e "${MAGENTA} |  _ \\ / _\` | __/ __| '_ \\  | |_) / _ \\ \\ / / |/ _ \\ \\ /\\ / /${NC}"
echo -e "${MAGENTA} | |_) | (_| | || (__| | | | |  _ <  __/\\ V /| |  __/\\ V  V / ${NC}"
echo -e "${MAGENTA} |____/ \\__,_|\\__\\___|_| |_| |_| \\_\\___| \\_/ |_|\\___| \\_/\\_/  ${NC}"
echo ""
echo -e "${GRAY}Batch PR review pipeline with Jira integration${NC}"
echo ""

# ── Reset ──────────────────────────────────────────────────────────────────

if [[ "$RESET" == "true" ]]; then
    if [[ -d "$REVIEWS_DIR" ]]; then
        rm -rf "$REVIEWS_DIR"
        echo -e "${YELLOW}Reset: Cleared reviews/ directory${NC}"
    fi
fi

# ── Prerequisites ──────────────────────────────────────────────────────────

if ! command -v jq &>/dev/null && ! command -v jq.exe &>/dev/null; then
    echo -e "${RED}jq not found on PATH.${NC}"
    exit 1
fi

if ! command -v gh &>/dev/null; then
    echo -e "${RED}gh (GitHub CLI) not found on PATH.${NC}"
    exit 1
fi

if [[ ! -f "$JIRA_ENV_FILE" ]]; then
    echo -e "${RED}Jira credentials not found at $JIRA_ENV_FILE${NC}"
    exit 1
fi

if [[ "$DRY_RUN" != "true" ]] && [[ "$TRIAGE_ONLY" != "true" ]]; then
    require_sandbox
fi

# ── State setup ────────────────────────────────────────────────────────────

mkdir -p "$REVIEWS_DIR"
touch "$ACTIVITY_LOG"

write_log "Batch review started (max_prs=$MAX_PRS, dry_run=$DRY_RUN, triage_only=$TRIAGE_ONLY)"

echo -e "Max PRs:             ${CYAN}$MAX_PRS${NC}"
echo -e "Timeout per PR:      ${CYAN}${TIMEOUT_MINUTES}m${NC}"
echo -e "Max passes:          ${CYAN}$MAX_PASSES${NC}"
echo -e "Severity threshold:  ${CYAN}$SEVERITY_THRESHOLD${NC}"
echo -e "Dry run:             ${CYAN}$DRY_RUN${NC}"
echo -e "Triage only:         ${CYAN}$TRIAGE_ONLY${NC}"
echo -e "Skip Jira:           ${CYAN}$SKIP_JIRA${NC}"
echo ""

# ── Concurrency guard ─────────────────────────────────────────────────────

GLOBAL_LOCK="$REVIEWS_DIR/.lock-global"

acquire_global_lock() {
    if [[ -f "$GLOBAL_LOCK" ]]; then
        local lock_age lock_pid lock_time
        lock_pid=$(cat "$GLOBAL_LOCK" 2>/dev/null | head -1)
        lock_time=$(stat -c %Y "$GLOBAL_LOCK" 2>/dev/null || stat -f %m "$GLOBAL_LOCK" 2>/dev/null || echo 0)
        local now
        now=$(date +%s)
        local age=$(( now - lock_time ))

        if [[ "$age" -gt 3600 ]]; then
            echo -e "${YELLOW}Stale global lock detected (${age}s old). Stealing.${NC}"
            write_log "Stole stale global lock (${age}s old, pid=$lock_pid)" "WARN"
        else
            echo -e "${RED}Another review-prs.sh is running (lock age: ${age}s, pid: $lock_pid).${NC}"
            echo -e "${RED}Wait for it to finish or remove $GLOBAL_LOCK${NC}"
            exit 1
        fi
    fi
    echo $$ > "$GLOBAL_LOCK"
}

release_global_lock() {
    rm -f "$GLOBAL_LOCK"
}

acquire_pr_lock() {
    local pr_number="$1"
    local lock_file="$REVIEWS_DIR/.lock-$pr_number"
    if [[ -f "$lock_file" ]]; then
        local lock_time
        lock_time=$(stat -c %Y "$lock_file" 2>/dev/null || stat -f %m "$lock_file" 2>/dev/null || echo 0)
        local now
        now=$(date +%s)
        local age=$(( now - lock_time ))
        if [[ "$age" -gt 3600 ]]; then
            write_log "Stole stale PR lock for #$pr_number (${age}s old)" "WARN"
        else
            return 1
        fi
    fi
    echo $$ > "$lock_file"
    return 0
}

release_pr_lock() {
    local pr_number="$1"
    rm -f "$REVIEWS_DIR/.lock-$pr_number"
}

if [[ "$DRY_RUN" != "true" ]]; then
    acquire_global_lock
    trap 'release_global_lock' EXIT
fi

# ── Helper functions ───────────────────────────────────────────────────────

# Read a field from a PR state file
pr_state_field() {
    local pr_number="$1"
    local field="$2"
    local state_file="$REVIEWS_DIR/${pr_number}.json"
    if [[ -f "$state_file" ]]; then
        jq -r "$field" < "$state_file"
    else
        echo ""
    fi
}

# Check if a PR has already converged
is_pr_converged() {
    local pr_number="$1"
    local converged
    converged=$(pr_state_field "$pr_number" '.convergence.converged // false')
    [[ "$converged" == "true" ]]
}

# Extract story key from branch name (e.g., feature/WH-101-slug -> WH-101)
# NOTE: Update the grep pattern to match your project key
extract_story_key() {
    local branch="$1"
    echo "$branch" | grep -oP '__PROJECT_KEY__-\d+' | head -1
}

# Determine severity rank (lower = more severe)
severity_rank() {
    case "$1" in
        CRITICAL)   echo 0 ;;
        IMPORTANT)  echo 1 ;;
        SUGGESTION) echo 2 ;;
        *)          echo 3 ;;
    esac
}

# Check if a severity meets the threshold
meets_severity_threshold() {
    local severity="$1"
    local sev_rank thr_rank
    sev_rank=$(severity_rank "$severity")
    thr_rank=$(severity_rank "$SEVERITY_THRESHOLD")
    [[ "$sev_rank" -le "$thr_rank" ]]
}

# ── Phase 1: PR Discovery ─────────────────────────────────────────────────

echo -e "${CYAN}── Phase 1: PR Discovery ──${NC}"

pr_json=$(gh pr list --state open --json number,title,headRefName,baseRefName,additions,deletions,labels 2>/dev/null || echo "[]")
total_prs=$(echo "$pr_json" | jq 'length')

if [[ "$total_prs" -eq 0 ]]; then
    echo -e "${GREEN}No open PRs found.${NC}"
    write_log "No open PRs found."
    exit 0
fi

echo -e "${GRAY}Found $total_prs open PR(s)${NC}"

# Filter PRs
filtered_prs=$(echo "$pr_json" | jq --argjson max "$MAX_PRS" '
    [.[] |
        # Filter out dependabot
        select(.headRefName | test("^dependabot/") | not) |
        # Filter out PRs targeting non-main
        select(.baseRefName == "main")
    ] | .[:$max]
')
filtered_count=$(echo "$filtered_prs" | jq 'length')

# Apply re-review filter if needed
if [[ "$RE_REVIEW_ONLY" == "true" ]]; then
    echo -e "${GRAY}Re-review mode: filtering to previously reviewed PRs only${NC}"
    re_review_list="[]"
    for (( idx=0; idx<filtered_count; idx++ )); do
        pr_num=$(echo "$filtered_prs" | jq -r ".[$idx].number")
        state_file="$REVIEWS_DIR/${pr_num}.json"
        if [[ -f "$state_file" ]]; then
            converged=$(jq -r '.convergence.converged // false' < "$state_file")
            if [[ "$converged" != "true" ]]; then
                re_review_list=$(echo "$re_review_list" | jq --argjson pr "$(echo "$filtered_prs" | jq ".[$idx]")" '. + [$pr]')
            fi
        fi
    done
    filtered_prs="$re_review_list"
    filtered_count=$(echo "$filtered_prs" | jq 'length')
fi

# Also skip already-converged PRs (unless re-review mode)
if [[ "$RE_REVIEW_ONLY" != "true" ]]; then
    non_converged="[]"
    for (( idx=0; idx<filtered_count; idx++ )); do
        pr_num=$(echo "$filtered_prs" | jq -r ".[$idx].number")
        if ! is_pr_converged "$pr_num"; then
            non_converged=$(echo "$non_converged" | jq --argjson pr "$(echo "$filtered_prs" | jq ".[$idx]")" '. + [$pr]')
        else
            echo -e "${GRAY}  SKIP PR #$pr_num: already converged${NC}"
        fi
    done
    filtered_prs="$non_converged"
    filtered_count=$(echo "$filtered_prs" | jq 'length')
fi

echo -e "${CYAN}PRs to process: $filtered_count${NC}"
echo ""

if [[ "$filtered_count" -eq 0 ]]; then
    echo -e "${GREEN}No PRs need review.${NC}"
    write_log "No PRs need review."
    exit 0
fi

# Print PR table
echo -e "${CYAN}PR  │ Branch                                          │ +/-${NC}"
echo -e "${GRAY}────┼─────────────────────────────────────────────────┼────────${NC}"
for (( idx=0; idx<filtered_count; idx++ )); do
    pr_num=$(echo "$filtered_prs" | jq -r ".[$idx].number")
    branch=$(echo "$filtered_prs" | jq -r ".[$idx].headRefName")
    adds=$(echo "$filtered_prs" | jq -r ".[$idx].additions")
    dels=$(echo "$filtered_prs" | jq -r ".[$idx].deletions")
    printf "%-4s│ %-48s│ ${GREEN}+%s${NC} ${RED}-%s${NC}\n" "#$pr_num" "$branch" "$adds" "$dels"
done
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${GRAY}[DRY RUN] Would process $filtered_count PR(s)${NC}"
    write_log "DRY RUN: $filtered_count PR(s) discovered"
    exit 0
fi

# ── Phase 2: Triage ───────────────────────────────────────────────────────

echo -e "${CYAN}── Phase 2: Triage ──${NC}"

for (( idx=0; idx<filtered_count; idx++ )); do
    pr_num=$(echo "$filtered_prs" | jq -r ".[$idx].number")
    branch=$(echo "$filtered_prs" | jq -r ".[$idx].headRefName")
    title=$(echo "$filtered_prs" | jq -r ".[$idx].title")
    story_key=$(extract_story_key "$branch")

    state_file="$REVIEWS_DIR/${pr_num}.json"

    # Skip triage if already triaged and not re-reviewing
    if [[ -f "$state_file" ]]; then
        existing_triage=$(jq -r '.triage.category // empty' < "$state_file")
        if [[ -n "$existing_triage" ]] && [[ "$RE_REVIEW_ONLY" != "true" ]]; then
            echo -e "${GRAY}  PR #$pr_num: already triaged ($existing_triage)${NC}"
            continue
        fi
    fi

    echo -e "${CYAN}  Triaging PR #$pr_num ($branch)...${NC}"

    # Get diff and changed files
    pr_diff=$(gh pr diff "$pr_num" 2>/dev/null || echo "")
    changed_files=$(echo "$pr_diff" | grep '^diff --git' | sed 's|diff --git a/\(.*\) b/.*|\1|' || echo "")

    # Auto-detect category from changed files
    has_ui_files=false
    has_test_files=false
    has_backend_files=false
    has_config_files=false
    has_source_files=false

    while IFS= read -r file; do
        [[ -z "$file" ]] && continue
        case "$file" in
            *.test.ts|*.test.tsx|*.spec.ts|*.spec.tsx)
                has_test_files=true ;;
            apps/web/*|*.tsx|*.css)
                has_ui_files=true; has_source_files=true ;;
            apps/api/*|convex/*)
                has_backend_files=true; has_source_files=true ;;
            *.ts|*.js)
                has_source_files=true ;;
            *.json|*.md|*.yml|*.yaml|.gitignore|.gitattributes|biome.json)
                has_config_files=true ;;
        esac
    done <<< "$changed_files"

    # Classify
    category="mixed"
    if [[ "$has_source_files" != "true" ]] && [[ "$has_config_files" == "true" ]]; then
        category="config-only"
    elif [[ "$has_test_files" == "true" ]] && [[ "$has_ui_files" != "true" ]] && [[ "$has_backend_files" != "true" ]]; then
        category="test-only"
    elif [[ "$has_ui_files" == "true" ]] && [[ "$has_backend_files" != "true" ]]; then
        category="ui-heavy"
    elif [[ "$has_backend_files" == "true" ]] && [[ "$has_ui_files" != "true" ]]; then
        category="backend-only"
    fi

    needs_ui_review=false
    if [[ "$has_ui_files" == "true" ]]; then
        needs_ui_review=true
    fi

    # Initialize or update state file
    now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    if [[ -f "$state_file" ]]; then
        # Update triage in existing state
        tmp=$(mktemp)
        jq --arg cat "$category" \
           --argjson has_ui "$has_ui_files" \
           --argjson has_test "$has_test_files" \
           --argjson needs_ui "$needs_ui_review" \
           --arg triaged_at "$now" \
           '.triage = {
               category: $cat,
               has_ui_files: $has_ui,
               has_test_files: $has_test,
               needs_ui_review: $needs_ui,
               triaged_at: $triaged_at
           }' < "$state_file" > "$tmp" && mv "$tmp" "$state_file"
    else
        # Create new state file
        jq -n \
            --argjson pr_num "$pr_num" \
            --arg branch "$branch" \
            --arg story_key "${story_key:-}" \
            --arg cat "$category" \
            --argjson has_ui "$has_ui_files" \
            --argjson has_test "$has_test_files" \
            --argjson needs_ui "$needs_ui_review" \
            --arg triaged_at "$now" \
            --argjson max_passes "$MAX_PASSES" \
            '{
                pr_number: $pr_num,
                branch: $branch,
                story_key: $story_key,
                triage: {
                    category: $cat,
                    has_ui_files: $has_ui,
                    has_test_files: $has_test,
                    needs_ui_review: $needs_ui,
                    triaged_at: $triaged_at
                },
                current_pass: 0,
                max_passes: $max_passes,
                status: "triaged",
                passes: [],
                fix_tickets_created: [],
                convergence: {
                    critical_by_pass: [],
                    converged: false,
                    stop_reason: null
                }
            }' > "$state_file"
    fi

    echo -e "${GREEN}  PR #$pr_num: $category${NC}"
    write_log "Triaged PR #$pr_num ($branch): $category"
done

# Triage summary table
echo ""
echo -e "${CYAN}Triage Summary:${NC}"
echo -e "${CYAN}PR  │ Category      │ UI Review │ Story${NC}"
echo -e "${GRAY}────┼───────────────┼───────────┼──────────${NC}"
for (( idx=0; idx<filtered_count; idx++ )); do
    pr_num=$(echo "$filtered_prs" | jq -r ".[$idx].number")
    state_file="$REVIEWS_DIR/${pr_num}.json"
    if [[ -f "$state_file" ]]; then
        cat_val=$(jq -r '.triage.category // "?"' < "$state_file")
        ui_val=$(jq -r '.triage.needs_ui_review // false' < "$state_file")
        story_val=$(jq -r '.story_key // "?"' < "$state_file")
        ui_display="no"
        [[ "$ui_val" == "true" ]] && ui_display="yes"
        printf "%-4s│ %-14s│ %-10s│ %s\n" "#$pr_num" "$cat_val" "$ui_display" "$story_val"
    fi
done
echo ""

if [[ "$TRIAGE_ONLY" == "true" ]]; then
    echo -e "${GRAY}Triage only mode — stopping here.${NC}"
    write_log "Triage only run complete."
    exit 0
fi

# ── Phase 3: Review ───────────────────────────────────────────────────────

echo -e "${CYAN}── Phase 3: Review ──${NC}"

# stream-json jq filter for live output
stream_text='select(.type == "assistant").message.content[]? | select(.type == "text").text // empty | gsub("\n"; "\r\n") | . + "\r\n\n"'

for (( idx=0; idx<filtered_count; idx++ )); do
    pr_num=$(echo "$filtered_prs" | jq -r ".[$idx].number")
    branch=$(echo "$filtered_prs" | jq -r ".[$idx].headRefName")
    state_file="$REVIEWS_DIR/${pr_num}.json"

    # Check PR still open
    pr_state=$(gh pr view "$pr_num" --json state 2>/dev/null | jq -r '.state // "UNKNOWN"')
    if [[ "$pr_state" != "OPEN" ]]; then
        echo -e "${YELLOW}  SKIP PR #$pr_num: state is $pr_state${NC}"
        # Update state
        tmp=$(mktemp)
        jq --arg reason "pr-$pr_state" \
            '.convergence.converged = true | .convergence.stop_reason = $reason | .status = "closed"' \
            < "$state_file" > "$tmp" && mv "$tmp" "$state_file"
        write_log "SKIP PR #$pr_num: $pr_state"
        continue
    fi

    # Check pass limits
    current_pass=$(jq -r '.current_pass // 0' < "$state_file")
    max_p=$(jq -r '.max_passes // 3' < "$state_file")
    if [[ "$current_pass" -ge "$max_p" ]]; then
        echo -e "${YELLOW}  SKIP PR #$pr_num: max passes ($max_p) reached${NC}"
        tmp=$(mktemp)
        jq '.convergence.stop_reason = "max-passes" | .status = "reviewed"' \
            < "$state_file" > "$tmp" && mv "$tmp" "$state_file"
        write_log "SKIP PR #$pr_num: max passes reached"
        continue
    fi

    # Check for new commits since last pass
    head_sha=$(gh pr view "$pr_num" --json headRefOid 2>/dev/null | jq -r '.headRefOid // ""')
    if [[ "$current_pass" -gt 0 ]]; then
        last_sha=$(jq -r '.passes[-1].head_sha // ""' < "$state_file")
        if [[ "$head_sha" == "$last_sha" ]]; then
            echo -e "${YELLOW}  SKIP PR #$pr_num: no new commits since pass $current_pass${NC}"

            # Check stop conditions for re-review
            last_critical=$(jq '[.passes[-1].issue_counts.CRITICAL // 0] | .[0]' < "$state_file")
            if [[ "$current_pass" -ge 2 ]] && [[ "$last_critical" -eq 0 ]]; then
                tmp=$(mktemp)
                jq '.convergence.stop_reason = "no-critical-pass-2+" | .status = "reviewed"' \
                    < "$state_file" > "$tmp" && mv "$tmp" "$state_file"
            fi
            write_log "SKIP PR #$pr_num: no new commits"
            continue
        fi
    fi

    # Acquire PR lock
    if ! acquire_pr_lock "$pr_num"; then
        echo -e "${YELLOW}  SKIP PR #$pr_num: locked by another process${NC}"
        write_log "SKIP PR #$pr_num: locked"
        continue
    fi

    echo -e "${CYAN}  Reviewing PR #$pr_num ($branch)...${NC}"
    write_log "START review PR #$pr_num ($branch)"

    # Determine review aspects based on pass number and triage
    review_aspects="all"
    if [[ "$current_pass" -gt 0 ]]; then
        # Targeted re-review: build aspects from agents that found issues last time
        last_agents=$(jq -r '[.passes[-1].issues[]?.agent // empty] | unique | join(" ")' < "$state_file")
        if [[ -n "$last_agents" ]]; then
            # Map agent names to review aspects
            aspects=""
            for agent in $last_agents; do
                case "$agent" in
                    code-reviewer)          aspects="$aspects code" ;;
                    pr-test-analyzer)       aspects="$aspects tests" ;;
                    silent-failure-hunter)  aspects="$aspects errors" ;;
                    type-design-analyzer)   aspects="$aspects types" ;;
                    comment-analyzer)       aspects="$aspects comments" ;;
                    *)                      aspects="$aspects code" ;;
                esac
            done
            review_aspects=$(echo "$aspects" | xargs | tr ' ' '\n' | sort -u | tr '\n' ' ' | xargs)
        fi
    fi

    # Reset workspace and checkout the PR branch
    git checkout -f main 2>/dev/null || true
    git clean -fd 2>/dev/null || true
    git fetch origin "$branch" 2>/dev/null || true
    git checkout "$branch" 2>/dev/null || true
    git pull origin "$branch" 2>/dev/null || true

    # Build review prompt for sandbox
    review_prompt="Review PR #$pr_num on branch $branch.

Run the /review-pr command with these aspects: $review_aspects

After review completes, output the findings as structured JSON between <review-output> tags.
The JSON should be an array of issue objects with these fields:
- id: stable identifier (agent::file::line::slug)
- fingerprint: stable root-cause identifier that survives minor rewording or line movement
- agent: which review agent found this (e.g., code-reviewer, silent-failure-hunter)
- severity: CRITICAL, IMPORTANT, or SUGGESTION
- confidence: HIGH, MEDIUM, or LOW
- confidence_score: optional numeric confidence score if the agent uses one
- category: one of code, tests, errors, types, comments
- file: file path
- line: line number (integer)
- title: short description
- description: full description
- fix_suggestion: suggested fix

Example:
<review-output>
[
  {
    \"id\": \"code-reviewer::src/app.tsx::42::missing-null-check\",
    \"fingerprint\": \"code-reviewer::src/app.tsx::missing-null-check\",
    \"agent\": \"code-reviewer\",
    \"severity\": \"CRITICAL\",
    \"confidence\": \"HIGH\",
    \"confidence_score\": 95,
    \"category\": \"code\",
    \"file\": \"src/app.tsx\",
    \"line\": 42,
    \"title\": \"Missing null check\",
    \"description\": \"The value could be null when accessed\",
    \"fix_suggestion\": \"Add null check before accessing property\"
  }
]
</review-output>

If no issues are found, output:
<review-output>
[]
</review-output>"

    # Refresh OAuth token before sandbox run
    refresh_oauth_token || { write_log "Token refresh failed for PR #$pr_num" "ERROR"; release_pr_lock "$pr_num"; continue; }

    # Run sandbox review
    sandbox_exit=0
    sandbox_tmpfile=$(mktemp)

    timeout_secs=$(( TIMEOUT_MINUTES * 60 ))

    docker sandbox run "$SANDBOX_NAME" -- \
        --verbose \
        --print \
        --output-format stream-json \
        "$review_prompt" \
    2>/dev/null \
    | grep --line-buffered '^{' \
    | tee "$sandbox_tmpfile" \
    | jq --unbuffered -rj "$stream_text" \
    || sandbox_exit=$?

    # Check sandbox result
    if grep -q '"type":"result"' "$sandbox_tmpfile" 2>/dev/null; then
        write_log "Sandbox review completed for PR #$pr_num"
    else
        write_log "Sandbox review may have failed for PR #$pr_num (exit=$sandbox_exit)" "WARN"
    fi

    # Extract review output from sandbox results
    # Get all text content from the sandbox output
    sandbox_output=$(jq -rs '[.[] | select(.type == "assistant").message.content[]? | select(.type == "text").text // empty] | join("")' < "$sandbox_tmpfile" 2>/dev/null || echo "")
    rm -f "$sandbox_tmpfile"

    # Parse review findings from <review-output> tags
    review_json="[]"
    if echo "$sandbox_output" | grep -q '<review-output>'; then
        review_json=$(echo "$sandbox_output" | sed -n '/<review-output>/,/<\/review-output>/p' | sed '1d;$d' | tr -d '\r')
        # Validate JSON
        if ! echo "$review_json" | jq '.' >/dev/null 2>&1; then
            write_log "Failed to parse review JSON for PR #$pr_num" "WARN"
            review_json="[]"
        fi
    fi

    # Iterative-pass admissibility filter:
    # - keep previously-seen findings by fingerprint/id
    # - admit new HIGH-confidence findings only in files changed since last pass
    # - admit new CRITICAL findings at HIGH/MEDIUM confidence anywhere
    if [[ "$current_pass" -gt 0 ]]; then
        changed_files_json=$(git diff --name-only "$last_sha" "$head_sha" 2>/dev/null | jq -R -s 'split("\n") | map(select(length > 0))')
        previous_issue_keys=$(jq '[.passes[-1].issues[]? | (.fingerprint // .id // empty)] | unique' < "$state_file")
        pre_filter_issue_count=$(echo "$review_json" | jq 'length')

        review_json=$(echo "$review_json" | jq \
            --argjson previous_issue_keys "$previous_issue_keys" \
            --argjson changed_files "$changed_files_json" '
            ($previous_issue_keys | map({ key: ., value: true }) | from_entries) as $previous |
            ($changed_files | map({ key: ., value: true }) | from_entries) as $changed |
            map(
                .__match_key = (.fingerprint // .id // "") |
                .__confidence = ((.confidence // "HIGH") | ascii_downcase) |
                .__severity = ((.severity // "SUGGESTION") | ascii_downcase)
            ) |
            map(select(
                (($previous[.__match_key] // false) == true) or
                (
                    .__severity == "critical" and
                    (.__confidence == "high" or .__confidence == "medium")
                ) or
                (
                    .__confidence == "high" and
                    (($changed[.file] // false) == true)
                )
            )) |
            map(del(.__match_key, .__confidence, .__severity))
            ')

        post_filter_issue_count=$(echo "$review_json" | jq 'length')
        dropped_issue_count=$(( pre_filter_issue_count - post_filter_issue_count ))
        if [[ "$dropped_issue_count" -gt 0 ]]; then
            write_log "Filtered $dropped_issue_count inadmissible iterative finding(s) for PR #$pr_num (new non-critical findings must be HIGH confidence in changed files)." "INFO"
        fi
    fi

    # Count issues by severity
    critical_count=$(echo "$review_json" | jq '[.[] | select(.severity == "CRITICAL")] | length')
    important_count=$(echo "$review_json" | jq '[.[] | select(.severity == "IMPORTANT")] | length')
    suggestion_count=$(echo "$review_json" | jq '[.[] | select(.severity == "SUGGESTION")] | length')
    total_issues=$(echo "$review_json" | jq 'length')

    new_pass=$(( current_pass + 1 ))

    # Update state file with pass results
    tmp=$(mktemp)
    jq --argjson pass_num "$new_pass" \
       --arg head_sha "$head_sha" \
       --argjson issues "$review_json" \
       --argjson critical "$critical_count" \
       --argjson important "$important_count" \
       --argjson suggestion "$suggestion_count" \
       '
       .current_pass = $pass_num |
       .status = "reviewed" |
       .passes += [{
           pass_number: $pass_num,
           head_sha: $head_sha,
           issues: $issues,
           issue_counts: {
               CRITICAL: $critical,
               IMPORTANT: $important,
               SUGGESTION: $suggestion
           }
       }] |
       .convergence.critical_by_pass += [$critical]
       ' < "$state_file" > "$tmp" && mv "$tmp" "$state_file"

    # Report
    if [[ "$total_issues" -eq 0 ]]; then
        echo -e "${GREEN}  PR #$pr_num: CLEAN (0 issues)${NC}"
    else
        echo -e "${YELLOW}  PR #$pr_num: $total_issues issue(s) (${RED}$critical_count C${NC}, ${YELLOW}$important_count I${NC}, ${GRAY}$suggestion_count S${NC})${NC}"
    fi

    # Check convergence: zero CRITICAL+IMPORTANT = eligible for auto-merge
    if [[ "$critical_count" -eq 0 ]] && [[ "$important_count" -eq 0 ]]; then
        tmp=$(mktemp)
        jq '.convergence.converged = true | .convergence.stop_reason = "clean"' \
            < "$state_file" > "$tmp" && mv "$tmp" "$state_file"
    fi

    write_log "DONE review PR #$pr_num: pass $new_pass, $critical_count CRITICAL, $important_count IMPORTANT, $suggestion_count SUGGESTION"

    release_pr_lock "$pr_num"

    # Restore workspace
    git checkout -f main 2>/dev/null || true
    __INSTALL_COMMAND__ --silent 2>/dev/null || true
done

echo ""

# ── Phase 4: Jira Ticket Creation ─────────────────────────────────────────

if [[ "$SKIP_JIRA" != "true" ]]; then
    echo -e "${CYAN}── Phase 4: Jira Ticket Creation ──${NC}"

    tickets_created=0

    for (( idx=0; idx<filtered_count; idx++ )); do
        pr_num=$(echo "$filtered_prs" | jq -r ".[$idx].number")
        state_file="$REVIEWS_DIR/${pr_num}.json"

        [[ ! -f "$state_file" ]] && continue

        status=$(jq -r '.status // ""' < "$state_file")
        [[ "$status" != "reviewed" ]] && continue

        # Get the latest pass issues
        issues=$(jq '.passes[-1].issues // []' < "$state_file")
        issue_count=$(echo "$issues" | jq 'length')
        [[ "$issue_count" -eq 0 ]] && continue

        # Get story key for parent linking
        story_key=$(jq -r '.story_key // ""' < "$state_file")
        if [[ -z "$story_key" ]]; then
            write_log "SKIP Jira for PR #$pr_num: no story key" "WARN"
            continue
        fi

        # Check for existing fix tickets to avoid duplicates
        existing_tickets=$(jq '[.fix_tickets_created[].issue_ids // [] | .[]] | unique' < "$state_file")

        # Group issues by directory for smaller fix tickets
        # Filter to issues meeting severity threshold
        eligible_issues=$(echo "$issues" | jq --arg threshold "$SEVERITY_THRESHOLD" '
            [.[] | select(
                ($threshold == "SUGGESTION") or
                ($threshold == "IMPORTANT" and (.severity == "CRITICAL" or .severity == "IMPORTANT")) or
                ($threshold == "CRITICAL" and .severity == "CRITICAL")
            )]
        ')
        eligible_count=$(echo "$eligible_issues" | jq 'length')

        if [[ "$eligible_count" -eq 0 ]]; then
            echo -e "${GRAY}  PR #$pr_num: no issues at or above $SEVERITY_THRESHOLD${NC}"
            continue
        fi

        # Group by directory
        groups=$(echo "$eligible_issues" | jq -r '
            group_by(.file | split("/")[:-1] | join("/")) |
            map({
                dir: (.[0].file | split("/")[:-1] | join("/")),
                issues: .
            })
        ')
        group_count=$(echo "$groups" | jq 'length')

        echo -e "${CYAN}  PR #$pr_num: creating $group_count ticket(s)...${NC}"

        for (( g=0; g<group_count; g++ )); do
            group=$(echo "$groups" | jq ".[$g]")
            group_dir=$(echo "$group" | jq -r '.dir')
            group_issues=$(echo "$group" | jq '.issues')
            first_issue=$(echo "$group_issues" | jq '.[0]')

            # Check for duplicates
            first_id=$(echo "$first_issue" | jq -r '.id // ""')
            is_dup=$(echo "$existing_tickets" | jq --arg id "$first_id" 'any(. == $id)')
            if [[ "$is_dup" == "true" ]]; then
                echo -e "${GRAY}    SKIP: duplicate ticket for $first_id${NC}"
                continue
            fi

            # Determine issue type: Bug for behavior issues, Task for quality
            first_severity=$(echo "$first_issue" | jq -r '.severity')
            first_agent=$(echo "$first_issue" | jq -r '.agent // "code-reviewer"')
            first_title=$(echo "$first_issue" | jq -r '.title // "Review finding"')

            # Bug: incorrect behavior, null checks, logic errors, silent failures
            # Task: code quality, style, naming, type design, test coverage
            issue_type_id="$TASK_TYPE_ID"
            if [[ "$first_agent" == "silent-failure-hunter" ]] || [[ "$first_agent" == "code-reviewer" && "$first_severity" == "CRITICAL" ]]; then
                issue_type_id="$BUG_TYPE_ID"
            fi

            # Build summary
            summary="[review-fix] PR#$pr_num: $first_title"
            # Truncate to 80 chars
            summary="${summary:0:80}"

            # Build description
            description=$(echo "$group_issues" | jq -r '
                map("[\(.severity)] \(.file):\(.line) - \(.title)\n\(.description)\nFix: \(.fix_suggestion // "N/A")\n")
                | join("\n---\n")
            ')

            # Create Jira issue
            created_key=$(jira_create_issue "$summary" "$description" "$issue_type_id" '["review-fix"]' "$story_key" || echo "")

            if [[ -n "$created_key" ]] && [[ "$created_key" != "null" ]]; then
                echo -e "${GREEN}    Created $created_key: $summary${NC}"
                write_log "Created Jira $created_key for PR #$pr_num ($first_title)"

                # Transition to Ready
                jira_transition_to "$created_key" "Ready" 2>/dev/null || true

                # Record in state
                issue_ids=$(echo "$group_issues" | jq '[.[].id]')
                now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
                tmp=$(mktemp)
                jq --arg key "$created_key" \
                   --argjson ids "$issue_ids" \
                   --arg created_at "$now" \
                   '.fix_tickets_created += [{
                       jira_key: $key,
                       issue_ids: $ids,
                       created_at: $created_at
                   }]' < "$state_file" > "$tmp" && mv "$tmp" "$state_file"

                (( tickets_created++ )) || true
            else
                echo -e "${RED}    FAIL: could not create ticket for PR #$pr_num ($first_title)${NC}"
                write_log "FAIL: Jira creation failed for PR #$pr_num ($first_title)" "ERROR"
            fi
        done
    done

    echo -e "${GRAY}  Tickets created: $tickets_created${NC}"
    echo ""
else
    echo -e "${GRAY}Skipping Jira ticket creation (--skip-jira)${NC}"
    echo ""
fi

# ── Phase 5: Auto-Merge Clean PRs ─────────────────────────────────────────

echo -e "${CYAN}── Phase 5: Auto-Merge Clean PRs ──${NC}"

merged_count=0

for (( idx=0; idx<filtered_count; idx++ )); do
    pr_num=$(echo "$filtered_prs" | jq -r ".[$idx].number")
    state_file="$REVIEWS_DIR/${pr_num}.json"

    [[ ! -f "$state_file" ]] && continue

    converged=$(jq -r '.convergence.converged // false' < "$state_file")
    stop_reason=$(jq -r '.convergence.stop_reason // ""' < "$state_file")

    if [[ "$converged" == "true" ]] && [[ "$stop_reason" == "clean" ]]; then
        # Verify PR is still open and mergeable
        pr_state=$(gh pr view "$pr_num" --json state,mergeable 2>/dev/null || echo '{}')
        state_val=$(echo "$pr_state" | jq -r '.state // "UNKNOWN"')
        mergeable=$(echo "$pr_state" | jq -r '.mergeable // "UNKNOWN"')

        if [[ "$state_val" != "OPEN" ]]; then
            echo -e "${GRAY}  PR #$pr_num: already $state_val${NC}"
            continue
        fi

        if [[ "$mergeable" == "CONFLICTING" ]]; then
            echo -e "${YELLOW}  PR #$pr_num: has merge conflicts, skipping auto-merge${NC}"
            write_log "SKIP auto-merge PR #$pr_num: merge conflicts" "WARN"
            continue
        fi

        echo -e "${CYAN}  Auto-merging PR #$pr_num...${NC}"

        if gh pr merge "$pr_num" --squash --delete-branch 2>/dev/null; then
            echo -e "${GREEN}  PR #$pr_num: merged!${NC}"
            write_log "AUTO-MERGED PR #$pr_num"

            # Update state
            tmp=$(mktemp)
            jq '.status = "merged"' < "$state_file" > "$tmp" && mv "$tmp" "$state_file"

            (( merged_count++ )) || true
        else
            echo -e "${RED}  PR #$pr_num: merge failed${NC}"
            write_log "FAIL auto-merge PR #$pr_num" "ERROR"
        fi
    fi
done

echo -e "${GRAY}  PRs merged: $merged_count${NC}"
echo ""

# ── Phase 6: Summary ──────────────────────────────────────────────────────

echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}         BATCH REVIEW SUMMARY               ${NC}"
echo -e "${CYAN}============================================${NC}"
echo ""
echo -e "${CYAN}PR  │ Category      │ Issues │ Tickets │ Merged │ Status${NC}"
echo -e "${GRAY}────┼───────────────┼────────┼─────────┼────────┼──────────${NC}"

for (( idx=0; idx<filtered_count; idx++ )); do
    pr_num=$(echo "$filtered_prs" | jq -r ".[$idx].number")
    state_file="$REVIEWS_DIR/${pr_num}.json"

    if [[ -f "$state_file" ]]; then
        cat_val=$(jq -r '.triage.category // "?"' < "$state_file")
        status_val=$(jq -r '.status // "?"' < "$state_file")

        # Issue count from latest pass
        issue_count=$(jq '[.passes[-1].issues // [] | length] | .[0]' < "$state_file")

        # Ticket count
        ticket_count=$(jq '[.fix_tickets_created // [] | length] | .[0]' < "$state_file")

        # Merged?
        merged_val="no"
        [[ "$status_val" == "merged" ]] && merged_val="yes"

        # Convergence status
        conv_val=$(jq -r '.convergence.stop_reason // .status // "?"' < "$state_file")

        printf "%-4s│ %-14s│ %-7s│ %-8s│ %-7s│ %s\n" \
            "#$pr_num" "$cat_val" "$issue_count" "$ticket_count" "$merged_val" "$conv_val"
    fi
done

echo ""
echo -e "${GRAY}Review state: $REVIEWS_DIR${NC}"
echo -e "${GRAY}Activity log: $ACTIVITY_LOG${NC}"

write_log "Batch review complete: $filtered_count PR(s) processed, $merged_count merged"

echo ""
