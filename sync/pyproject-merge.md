# pyproject.toml Merge Rules

## Strategy

Section-level replacement, not line-level diffing. This avoids merge conflicts and ensures template sections are always up to date.

## Process

1. Read the project's `pyproject.toml` in full
2. Read the template's `pyproject.toml` (rendered with resolved variables)
3. Identify section boundaries in both files
4. Replace target sections wholesale with the rendered template versions
5. Preserve ordering and comments outside replaced sections

## Sections to REPLACE

These sections are fully template-owned. Replace them entirely:

- `[tool.ruff]` and all `[tool.ruff.*]` subsections (e.g., `[tool.ruff.lint]`, `[tool.ruff.lint.per-file-ignores]`, `[tool.ruff.format]`)
- `[tool.ty]` and all `[tool.ty.*]` subsections
- `[tool.pydoclint]`
- `[tool.pytest.ini_options]`
- `[tool.poe.tasks]` and all `[tool.poe.tasks.*]` subsections
- `[tool.coverage.run]` and `[tool.coverage.report]`

## Sections to UNION MERGE

### `[dependency-groups]` → `dev`

- Parse the `dev` dependency list from both template and project
- Add any template dependencies that are missing from the project
- Keep all existing project dependencies (even if not in template)
- Do NOT downgrade or remove existing dependency version pins
- Preserve the project's ordering; append new deps at the end

## Sections to NEVER MODIFY

- `[build-system]` — project-specific build backend
- `[project]` — name, version, description, authors, license, classifiers, etc.
- `[project.urls]`
- `[project.optional-dependencies]`
- `[project.scripts]` / `[project.gui-scripts]` / `[project.entry-points]`
- `[tool.hatch.*]` or other build tool config
- Runtime `dependencies` under `[project]`

## Implementation Notes

- TOML sections are delimited by `[header]` lines. A section ends when the next `[header]` starts or the file ends.
- When replacing a section, include the header line and all content up to (but not including) the next header.
- The template `pyproject.toml` contains `{{ cookiecutter.project_slug }}` and `{{ cookiecutter.python_version }}` — render these before extracting sections.
- After merging, verify the result is valid TOML (no duplicate headers, proper formatting).
