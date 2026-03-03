# ADR-001: Python Tooling Choices

## Status

Accepted

## Context

This module needs linting, formatting, type checking, docstring validation, task running, and dependency management. Key requirements:
- Single-tool solutions where possible (fewer configs to maintain)
- Fast execution (developer experience matters)
- Python {{ cookiecutter.python_version }}+ compatibility

## Decision

| Concern | Tool | Why |
|---------|------|-----|
| Package/env management | **uv** | Fast, replaces pip + venv + pip-tools in one tool |
| Linting + formatting | **ruff** | Replaces flake8 + isort + black + dozens of plugins. Single config in `pyproject.toml` |
| Type checking | **ty** | Astral's type checker, designed to work alongside ruff. Fast |
| Docstring validation | **pydoclint** | Checks Google-style docstrings match function signatures |
| Task runner | **poethepoet (poe)** | Tasks defined in `pyproject.toml`, no Makefile needed |
| Testing | **pytest** | Industry standard, excellent plugin ecosystem |
| Pre-commit | **pre-commit** | Runs ruff, ty, pydoclint before each commit |

All tool configuration lives in `pyproject.toml`. Available tasks:

```
uv run poe lint        # ruff check
uv run poe format      # ruff format
uv run poe typecheck   # ty check
uv run poe doclint     # pydoclint
uv run poe test        # pytest
```

## Consequences

**Easier:**
- One `pyproject.toml` configures everything
- `uv run poe <task>` is the single entry point for all quality checks
- Ruff is fast enough to run on every save and every commit

**Harder:**
- ty is newer and less mature than mypy (some false positives may need `ignore` rules)
- Team members unfamiliar with uv need to install it (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
