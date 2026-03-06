# ReactTemplate

A [cookiecutter](https://github.com/cookiecutter/cookiecutter) template for modern React + TypeScript applications.

## Stack

- **Build:** Vite
- **Language:** TypeScript (strict, via `@total-typescript/tsconfig`)
- **Linter/Formatter:** Biome
- **Validation:** Zod 4
- **Styling:** Tailwind CSS + shadcn/ui (optional)
- **Testing:** Vitest + React Testing Library + Playwright (optional)
- **State:** TanStack Query (optional) + Zustand (optional)
- **Routing:** React Router v7 (optional)
- **CI:** GitHub Actions
- **AI:** Claude Code hooks, Cursor rules, Copilot instructions (configurable)

## Usage

```bash
cookiecutter path/to/ReactTemplate
```

## Template Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `project_name` | My App | Human-readable project name |
| `project_slug` | my-app | kebab-case directory name |
| `node_package_manager` | bun | bun, pnpm, or npm |
| `include_tanstack_query` | yes | TanStack Query for server state |
| `include_zustand` | yes | Zustand for client state |
| `include_router` | yes | React Router v7 |
| `include_shadcn` | yes | shadcn/ui component primitives |
| `include_playwright` | yes | Playwright E2E testing |
| `include_docker` | yes | Dockerfile + .dockerignore |
| `enable_precommit` | yes | husky + lint-staged |
| `include_docs` | yes | ADRs and standards docs |
| `license` | MIT | MIT, Apache-2.0, or Proprietary |
| `ai_tools` | all | claude, cursor, copilot, all, or none |

## Development

Run template self-tests:

```bash
cd ReactTemplate
pytest tests/
```
