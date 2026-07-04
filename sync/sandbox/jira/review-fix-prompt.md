# Review Fix Worker

Apply a targeted fix for Jira ticket {{STORY_KEY}}: {{STORY_SUMMARY}}

Parent story: {{PARENT_STORY}}
Target branch: {{BRANCH_NAME}}

## Step 0: Install Dependencies
Run `__INSTALL_COMMAND__` to ensure Linux-compatible binaries in node_modules.

## Step 1: Task Description

{{DESCRIPTION}}

## Step 2: Locate and Fix

- Find the issue in the codebase at the file/line specified
- Apply a minimal, targeted fix (<50 lines changed)
- Do NOT refactor surrounding code
- Do NOT create new files unless absolutely necessary
- Do NOT modify .claude/ directory

## Step 3: Verify

```bash
__TEST_COMMAND__ && __VERIFY_COMMAND__
```

Fix any failures. Retry up to 3 times.

## Step 4: Commit & Push

```bash
git add <specific-files>
git commit -m "{{STORY_KEY}} fix: <description>"
git push
```

## Outcome

After completing the fix, output exactly ONE of these markers:

- `<complete/>` — fix applied, tests pass, pushed
- `<blocked>reason</blocked>` — cannot fix (missing dependency, unclear requirement, etc.)
- `<false-positive>reason</false-positive>` — the reported issue is not actually a problem

## Rules

- Work on THIS fix only — do not address other issues
- Do NOT create branches — commit directly to {{BRANCH_NAME}}
- Do NOT create PRs — the PR already exists
- Do NOT modify .claude/ directory
- Keep changes minimal and focused
