# Sandbox Reference Implementations

Docker sandbox pipelines for autonomous Claude Code work. Two variants based on project management tool.

## Variants

### `jira/` — Jira-based sandbox

For projects using Jira for issue tracking. Features:
- JQL-based story fetching (status=Ready, type filtering, HITL exclusion)
- Dependency checking (blocked-by issue links)
- WIP limits
- Review pipeline (`review-prs.sh`) with auto-fix ticket creation
- Signal file completion detection

**Entry points:**
- `afk.sh` — main story automation loop
- `review-prs.sh` — batch PR review with Jira ticket creation

### `github/` — GitHub Issues-based sandbox

For projects using GitHub Issues for task tracking. Features:
- Label-based issue fetching (`gh issue list --label <label>`)
- Commit-based completion detection
- Auto-close issues on successful commit

**Entry point:**
- `once.sh` — issue processing loop

## Shared Infrastructure

Both variants share identical Docker plumbing:
- **OAuth refresh** — reads Claude token from `~/.claude/.credentials.json`, injects into `.env`
- **Docker sandbox** — uses `docker/sandbox-templates:claude-code` base image
- **BASH_ENV loader** — auto-exports `GH_TOKEN` in subprocesses
- **Claude wrapper** — injects OAuth token before calling real binary
- **Activity logging** — timestamped `.afk/activity.log`
- **Windows compatibility** — jq CRLF stripping, path conversion

## Runtime Variants

Each variant ships two Dockerfiles:
- `Dockerfile.bun` — for React/TypeScript projects (installs Bun + Lefthook)
- `Dockerfile.uv` — for Python projects (installs uv + python3-venv)

The `/template:add-sandbox` command selects the right one based on project detection.

## Placeholders

Reference files use `__PLACEHOLDER__` tokens that get replaced by `/template:add-sandbox`:

| Placeholder | Example value | Used in |
|---|---|---|
| `__PROJECT_SLUG__` | `my-app` | setup.sh, sandbox naming |
| `__INSTALL_COMMAND__` | `bun install` | prompt.md, afk.sh/once.sh |
| `__VERIFY_COMMAND__` | `bun run check` | prompt.md, afk.sh/once.sh |
| `__TEST_COMMAND__` | `bun run test` | prompt.md |
| `__DEV_COMMAND__` | `bun run dev` | .jira-project.json |
| `__DEV_URL__` | `http://localhost:5173` | .jira-project.json |
| `__PROJECT_KEY__` | `WH` | Jira JQL queries, .jira-project.json |
| `__JIRA_BASE_URL__` | `https://x.atlassian.net` | common.sh, .jira-project.json |
| `__AC_FIELD__` | `customfield_10182` | common.sh (acceptance criteria) |
| `__WIP_LIMIT__` | `3` | .sandbox-config.json |
| `__BOARD_ID__` | `100` | .jira-project.json |
| `__PROJECT_NAME__` | `My App` | .jira-project.json |
| `__ISSUE_LABEL__` | `ralph` | once.sh, .sandbox-config.json |
| `__RUNTIME__` | `uv` | setup.sh verification |

## Prerequisites

- Docker Desktop 4.40+ (with sandbox support)
- `jq` on PATH
- `gh` CLI authenticated
- For Jira: `~/.env.jira` with `JIRA_URL`, `JIRA_USERNAME`, `JIRA_API_TOKEN`
- For GitHub: `GH_TOKEN` in `.env`

## Installation

Use the `/template:add-sandbox` command from any project:
```
/template:add-sandbox
```

It will detect your project type, ask which variant you want, and generate the sandbox files.
