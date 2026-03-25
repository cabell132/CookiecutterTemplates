# AFK Story Worker

Implement Jira story {{STORY_KEY}}: {{STORY_SUMMARY}}

Type: {{STORY_TYPE}}

## Acceptance Criteria
{{ACCEPTANCE_CRITERIA}}

## Recent Commits (for context)
{{RECENT_COMMITS}}

## Step 0: Install Dependencies
Run `__INSTALL_COMMAND__` to ensure Linux-compatible binaries in node_modules.
The host workspace may have Windows/macOS binaries that won't work inside the container.

## Step 1: Create Branch
- Read CLAUDE.md for project conventions
- Create branch from main:
  - Story -> feature/{{STORY_KEY}}-<slug>
  - Bug -> fix/{{STORY_KEY}}-<slug>
  - Task -> chore/{{STORY_KEY}}-<slug>
- Push branch: git push -u origin <branch>

## Step 2: Explore & Plan
- Read CLAUDE.md and relevant docs
- Find similar patterns in the codebase
- Plan implementation as ordered TODO list

## Step 3: Implement via TDD
Read and follow CLAUDE.md for all conventions. Then for each TODO:
1. RED: Write ONE failing test
2. GREEN: Minimal code to pass
3. REFACTOR: Clean up while green

## Step 4: Verify
__TEST_COMMAND__ && __VERIFY_COMMAND__
Fix any failures. Retry up to 3 times.

## Step 5: Commit & Push
git add <specific-files>
git commit (message format below)
git push

Commit format:
  {{STORY_KEY}} <type>: <description>

  - Change 1
  - Change 2

  Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>

## Step 6: Create PR
gh pr create --base main --title "{{STORY_KEY}}: <summary>" --body "..."

PR body must include:
- ## Summary (bullet points)
- ## Test plan (how to verify)

## Rules
- Work on THIS story only
- Do NOT modify .claude/ directory
- Do NOT install new dependencies without clear need
- Keep changes <300 lines
- When done, write a signal file so the host can detect completion:
  - Success: `echo "COMPLETE" > .afk-signal`
  - Blocked: `echo "BLOCKED: reason" > .afk-signal`
  This is CRITICAL — the host polls this file to stop the sandbox. Without it, the sandbox runs until timeout.
