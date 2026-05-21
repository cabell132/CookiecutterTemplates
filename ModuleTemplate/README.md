# ModuleTemplate

Modern Cookiecutter template for Python modules powered by [uv](https://github.com/astral-sh/uv). Ships with a comprehensive quality enforcement stack designed for AI-assisted development with Pi and Claude.

## Features

- **PEP 621** `pyproject.toml` configured for uv with managed `uv.lock`
- **Ruff** — 50+ rule categories for linting and formatting
- **ty** — Astral's fast type checker (replaces mypy)
- **pydoclint** — Google-style docstring validation
- **poethepoet** — Task runner (`uv run poe <task>`)
- **pytest** + **pytest-cov** — Testing and coverage
- **Pre-commit hooks** — ruff + ty + pydoclint before every commit
- **Agent integration** — CLAUDE.md, AGENTS.md, Pi YAML hooks, python-pro agent
- **GitHub Actions CI** — lint + typecheck + doclint + test
- Optional **Typer CLI** skeleton
- Optional **MkDocs + Material** documentation
- Optional **Dockerfile**

## Usage

```bash
uv tool run cookiecutter ./ModuleTemplate
```

## Options

| Option | Default | Description |
|--------|---------|-------------|
| `full_name` | Cameron Bell | Author name |
| `email` | cabell132@hotmail.com | Author email |
| `github_username` | cameronbell | GitHub username |
| `project_name` | awesome-module | Human-readable project name |
| `project_slug` | *(auto)* | Python package name (snake_case) |
| `module_description` | A modern Python module. | Short description |
| `python_version` | 3.12 | Minimum Python version (>= 3.11) |
| `initial_version` | 0.1.0 | Starting version |
| `license` | MIT | MIT, Apache-2.0, or Proprietary |
| `include_cli` | typer | Typer CLI skeleton or none |
| `include_docs` | mkdocs | MkDocs + Material or none |
| `include_docker` | n | Include Dockerfile |
| `enable_precommit` | y | Install pre-commit hooks |

## Generated Project Tasks

```bash
uv run poe lint        # ruff check
uv run poe format      # ruff format
uv run poe typecheck   # ty check
uv run poe doclint     # pydoclint
uv run poe test        # pytest
uv run poe docs        # mkdocs serve (if enabled)
```

## Testing the Template

```bash
pytest tests/test_bake_template.py
```
