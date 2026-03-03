# Agent Instructions

## Package Manager
Use **uv**: `uv sync`, `uv run <cmd>`

Task runner: **poethepoet** via `uv run poe <task>`

| Command | Description |
|---------|-------------|
| `uv run poe format` | Format with ruff |
| `uv run poe lint` | Lint with ruff |
| `uv run poe typecheck` | Type check with ty |
| `uv run poe doclint` | Docstring lint with pydoclint |
| `uv run poe test` | Run pytest |

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
├── client.py          # Main client class
├── session.py         # HTTP session layer
├── base.py            # Base resource class
├── items.py           # Example resource (extend with new resources)
├── models.py          # Pydantic models
├── exceptions.py      # Exception hierarchy
├── cache_handler.py   # Token cache
├── utils.py           # Utilities
└── auth/              # Auth strategies
    ├── base.py
    ├── oauth.py
    └── utils.py
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
- Layout: `tests/unit/`, `tests/integration/`
- Coverage target: 80%+ on `{{ cookiecutter.project_slug }}/`
- Mock HTTP at session boundary, never make real API calls in unit tests
- Naming: `test_<what>_<expected_behavior>[_when_<condition>]`
- See `docs/standards/testing-strategy.md` for full strategy

## Error Handling
- All SDK errors inherit from `{{ cookiecutter.service_name }}BaseError`
- Use `{{ cookiecutter.service_name }}APIError.from_response()` for HTTP errors
- See `docs/standards/error-handling.md`

## Adding a New Resource
1. Create `{{ cookiecutter.project_slug }}/<resource>.py` extending `base.py`
2. Add Pydantic models to `models.py`
3. Register on the client in `client.py`
4. Add unit tests in `tests/unit/test_<resource>.py`

## Standards Docs
- `docs/standards/error-handling.md` — Exception patterns
- `docs/standards/logging-strategy.md` — Logging conventions
- `docs/standards/testing-strategy.md` — Test strategy
- `docs/decisions/` — Architecture Decision Records
