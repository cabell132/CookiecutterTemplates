# Sync Manifest

Defines which files to sync per template type. This is the source of truth for both
forward sync (`/template:to-project`) and reverse sync (`/template:to-template`), and
is read by `/template:drift` for audit comparisons.

## Template Source Paths

All templates are at: `C:\Users\Cameron\Documents\Python Scripts\AllTemplates`

Within each template, project files are in: `<TemplateName>/{{ cookiecutter.project_slug }}/`

---

## Python Templates (APISDKTemplate, ModuleTemplate)

### REPLACE (copy verbatim -- no Jinja variables in these files)

- `.claude/scripts/*.sh` -- all hook/script files (typically ~11 scripts)
- `.claude/agents/python-pro.md`

### RENDER then REPLACE (substitute Jinja variables)

These files contain `{{ cookiecutter.project_slug }}` or `{{ cookiecutter.python_version }}`:

- `.claude/settings.json` -- needs `project_slug` for `CLAUDE_CODE_TASK_LIST_ID`
- `.pre-commit-config.yaml` -- needs `project_slug` (only if `enable_precommit` is "yes")

### MERGE into `pyproject.toml`

See `sync/pyproject-merge.md` for detailed merge rules.

Replace these sections with rendered template versions:
- `[tool.ruff]` and all `[tool.ruff.*]` subsections
- `[tool.ty]` and all `[tool.ty.*]` subsections
- `[tool.pydoclint]`
- `[tool.pytest.ini_options]`
- `[tool.poe.tasks.*]` (all poe task definitions)
- `[tool.coverage.*]`

Union-merge `[dependency-groups] dev` -- add missing template deps, keep project additions.

### UPSTREAM (project --> template)

These file categories are compared during reverse sync and drift audits:

- `.claude/agents/*.md` -- compare against template agents
- `.claude/skills/*/` -- compare (no templates currently include skills)
- `.claude/commands/*.md` and `.claude/commands/*/` -- compare (no templates currently include commands)
- `.claude/scripts/*.sh` -- compare against template scripts
- `.claude/settings.json` -- compare hook entries (not whole file)
- `docs/standards/*.md` -- compare against template standards docs
- `docs/git/*.md` -- compare against template git docs
- `docs/decisions/*.md` -- compare (flag for user review)

### NEVER TOUCH

- Source code (`<project_slug>/`)
- Tests (`tests/`)
- `README.md`
- `LICENSE`
- Docs content (`docs/`) except `docs/standards/`, `docs/git/`, `docs/decisions/`
- `[build-system]` in pyproject.toml
- `[project]` and `[project.*]` in pyproject.toml (except `[project.scripts]` if template defines them)
- Source/runtime dependencies

---

## ReactTemplate

### REPLACE (copy verbatim -- no Jinja variables)

- `.claude/scripts/biome-format.sh`
- `.claude/scripts/block-destructive.sh`
- `.claude/scripts/protect-files.sh`
- `.claude/scripts/test-runner.sh`
- `.claude/scripts/typecheck.sh`
- `.claude/agents/react-pro.md`
- `biome.json`
- `eslint.jsdoc.cjs`
- `tsconfig.json`
- `tsconfig.app.json`
- `tsconfig.node.json`
- `vite.config.ts`
- `vitest.config.ts`

### RENDER then REPLACE (substitute Jinja variables)

- `.claude/settings.json` -- needs `project_slug` for `CLAUDE_CODE_TASK_LIST_ID`
- `.husky/pre-commit` -- only if `enable_precommit` is "yes"

### MERGE into `package.json`

See `sync/package-json-merge.md` for detailed merge rules.

- `scripts` -- full replacement (template-owned)
- `devDependencies` -- union merge (add missing template deps, keep project additions)
- `lint-staged` -- full replacement if `enable_precommit` is "yes"

### UPSTREAM (project --> template)

These file categories are compared during reverse sync and drift audits:

- `.claude/agents/*.md` -- compare against template agents
- `.claude/skills/*/` -- compare (no templates currently include skills)
- `.claude/commands/*.md` and `.claude/commands/*/` -- compare (no templates currently include commands)
- `.claude/scripts/*.sh` -- compare against template scripts
- `.claude/settings.json` -- compare hook entries (not whole file)
- `biome.json` -- compare (project may have refined rules worth promoting)
- `docs/standards/*.md` -- compare against template standards docs
- `docs/git/*.md` -- compare against template git docs
- `docs/decisions/*.md` -- compare (flag for user review)

### NEVER TOUCH

- Source code (`src/`)
- Tests (test files in `src/`)
- E2E tests (`e2e/`)
- `public/`
- `name`, `version`, `description`, `author`, `license` in package.json
- `dependencies` in package.json (project-owned runtime deps)
- `README.md`
- Docs content except `docs/standards/`, `docs/git/`, `docs/decisions/`

---

## Shared Infrastructure

These files should be identical across ALL supported templates. If promoted to one template,
they should be offered to all templates:

- `.claude/scripts/block-destructive.sh`
- `.claude/scripts/protect-files.sh`
- `.claude/scripts/check-file-length.sh`
- `docs/standards/error-handling.md` (language-adapted versions)
- `docs/standards/logging-strategy.md` (language-adapted versions)
- `docs/standards/testing-strategy.md` (language-adapted versions)
