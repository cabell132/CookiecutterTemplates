# Promotable Files

Defines which infrastructure file categories can be promoted from a project back to a
cookiecutter template via `/template:to-template`.

## Reference paths

- **AllTemplates:** This repo (resolved dynamically by the `/template:*` commands)
- **Template source files:** `<TemplateName>/{{ cookiecutter.project_slug }}/`

---

## Categories

| Category | Project path(s) | Template path(s) | Notes |
|----------|----------------|-------------------|-------|
| Agents | `.claude/agents/*.md` | `.claude/agents/*.md` | Python templates ship `python-pro.md`, React ships `react-pro.md`. New agents may be universal or template-specific. |
| Skills | `.claude/skills/*/` | `.claude/skills/*/` | Entire skill directories (`SKILL.md` + `references/`). No templates currently include skills, so any skill is new. |
| Commands | `.claude/commands/*.md`, `.claude/commands/*/` | `.claude/commands/*.md`, `.claude/commands/*/` | Project-local commands. No templates currently include commands. |
| Scripts | `.claude/scripts/*.sh` | `.claude/scripts/*.sh` | Hook scripts referenced by `.claude/settings.json`. If promoting a new script, also update `settings.json` in the template. |
| Hook config | `.claude/settings.json` | `.claude/settings.json` | Needs **hook-entry-level merge**, not whole-file replacement. Template version may contain `{{ cookiecutter }}` variables. |
| Standards docs | `docs/standards/*.md` | `docs/standards/*.md` | Guidelines docs. Usually template-portable as-is (no project-specific values). |
| Git docs | `docs/git/*.md` | `docs/git/*.md` | Git workflow and naming convention docs. Usually universal. |
| Decision records | `docs/decisions/*.md` | `docs/decisions/*.md` | Only promote template-level decisions (e.g., "initial tooling"). Flag project-specific decisions for user review. |

---

## Never promote

These files must never be copied back to a template:

- Source code (`<project_slug>/`, `src/`)
- Tests (`tests/`, test files in `src/`)
- `README.md`, `LICENSE`, `CHANGELOG.md`
- `pyproject.toml` / `package.json` (handled by merge rules, not file copy)
- `.template.json` (project metadata)
- `CLAUDE.md` (project-specific AI steering context)
- Lock files (`uv.lock`, `poetry.lock`, `package-lock.json`, `bun.lockb`)
- `.env`, credentials, secrets, API keys
- `.git/` and git hooks installed locally
- Data files, notebooks, generated output

---

## Templatisation rules

When promoting a file, replace project-specific literal values with Jinja variables:

| Literal value | Replace with |
|---------------|-------------|
| The value of `project_slug` | `{{ cookiecutter.project_slug }}` |
| The value of `python_version` | `{{ cookiecutter.python_version }}` |
| The value of `full_name` | `{{ cookiecutter.full_name }}` |
| The value of `email` | `{{ cookiecutter.email }}` |
| The value of `node_package_manager` | `{{ cookiecutter.node_package_manager }}` |
| The value of `service_name` (API only) | `{{ cookiecutter.service_name }}` |

**Rules:**
- Only substitute where the literal value appears in config paths, identifiers, or metadata fields
- Do **not** substitute inside free-text prose, comments, or docstrings -- these are likely project-specific
- Always show the user a preview diff of templatised changes before writing
- If the project slug is a common word (e.g., "utils", "app"), warn about potential false positives

---

## Universal vs template-specific

When the user selects files to promote, ask whether each should be:

- **Universal** -- copied to ALL supported templates (ModuleTemplate, APISDKTemplate, ReactTemplate)
- **Template-specific** -- copied only to the detected template type

**Guidance for the user:**

| Signal | Recommendation |
|--------|---------------|
| Script uses Python-only tools (ruff, pydoclint, ty, uv, poe) | Python templates only |
| Script uses JS-only tools (biome, tsc, vitest, bun) | React template only |
| Script is tool-agnostic (protect-files, block-destructive, check-file-length) | Universal |
| Agent has language-specific expertise | Template-specific |
| Agent is about general practices (code review, testing strategy) | Universal |
| Standards doc references language-specific patterns | Template-specific |
| Standards doc is about universal practices (error handling, logging) | Universal |
| Decision record | Almost never universal -- these are project context |

---

## Supported templates

The following templates support promotion:

- **ModuleTemplate** -- modern Python module
- **APISDKTemplate** -- Python API/SDK client
- **ReactTemplate** -- React + TypeScript

The **data-science-project-template** is excluded (legacy structure, no `.claude/` infrastructure).
