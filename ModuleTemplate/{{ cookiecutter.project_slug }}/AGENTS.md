# Agent Instructions

## Package Manager
Use **uv**: `uv sync`, `uv run <cmd>`

Task runner: **poethepoet** via `uv run poe <task>`

| Command | Description |
|---------|-------------|
| `uv run poe check` | Run all quality checks |
| `uv run poe format` | Format with ruff |
| `uv run poe format-check` | Verify formatting (no changes) |
| `uv run poe lint` | Lint with ruff |
| `uv run poe typecheck` | Type check with ty |
| `uv run poe doclint` | Docstring lint with pydoclint |
| `uv run poe test` | Run pytest with coverage |
| `uv run poe audit` | Dependency vulnerability scan |
{%- if cookiecutter.include_docs == "mkdocs" %}
| `uv run poe docs` | Serve MkDocs locally |
{%- endif %}

## Commit Attribution
AI commits MUST include:
```
Co-Authored-By: Claude <noreply@anthropic.com>
```

## Commit Messages
Follow conventional commits with issue key prefix:
```
<ISSUE-KEY> <type>(<scope>): <description>
```
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`, `ci`
- Imperative mood, no capitalization, no trailing period
- See `docs/git/naming-conventions.md` for full spec

## Project Structure
```
{{ cookiecutter.project_slug }}/
├── __init__.py
├── __main__.py        # python -m entry point
├── exceptions.py      # Exception hierarchy
{%- if cookiecutter.include_cli == "typer" %}
├── cli.py             # Typer CLI entry point
{%- endif %}
└── py.typed
```

## Code Style
- **Formatter/linter:** ruff (line-length 100)
- **Type checker:** ty
- **Docstrings:** Google style, validated by pydoclint
- **Imports:** Absolute only (no relative imports)
- Config in `pyproject.toml`

## Lint Hook
A stop hook at `.claude/hooks/lint.sh` runs ruff, ty, and pydoclint on modified Python files automatically. Fix all reported errors before committing.

## Testing
- Framework: pytest
- Layout: `tests/`
- Coverage target: 80%+ on `{{ cookiecutter.project_slug }}/`
- Naming: `test_<what>_<expected_behavior>[_when_<condition>]`
- See `docs/standards/testing-strategy.md` for full strategy

## Error Handling
- Define a module-level base exception (e.g., `{{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error`)
- All custom exceptions inherit from it
- See `docs/standards/error-handling.md`

## Adding a New Module
1. Create `{{ cookiecutter.project_slug }}/<module>.py`
2. Export public API from `__init__.py`
3. Add unit tests in `tests/test_<module>.py`
4. Add Google-style docstrings for pydoclint compliance

## Standards Docs
- `docs/standards/error-handling.md` — Exception patterns
- `docs/standards/logging-strategy.md` — Logging conventions
- `docs/standards/testing-strategy.md` — Test strategy
- `docs/decisions/` — Architecture Decision Records
