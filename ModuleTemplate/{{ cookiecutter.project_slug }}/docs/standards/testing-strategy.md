# Testing Strategy

When, what, and how to test {{ cookiecutter.project_name }}.

## Testing Pyramid

```
        ┌─────────┐
        │  E2E    │  10% — Full system round-trips (optional)
        ├─────────┤
        │ Integr. │  20% — Component interactions
        ├─────────┤
        │  Unit   │  70% — Functions, classes, isolated logic
        └─────────┘
```

Invest most effort in fast, isolated unit tests. Use integration tests for component interactions. E2E tests are optional and should be run separately.

## Framework

| Layer | Tool | Location |
|-------|------|----------|
| Unit | pytest | `tests/` |
| Integration | pytest | `tests/` |
| Coverage | pytest-cov | Config in `pyproject.toml` |

Run tests with:
```
uv run poe test
```

## What to Test

### Core logic — Required

The main functionality of the module. Correctness here prevents all downstream bugs.

- **Input validation:** Invalid inputs raise appropriate exceptions
- **Edge cases:** Empty inputs, boundary values, None handling
- **Return values:** Functions return expected types and values

### Public API — Required

- **Exported functions/classes:** Everything in `__init__.py.__all__` works as documented
- **Type contracts:** Arguments and return types match annotations

### Error handling — Required

- **Exception types:** Custom exceptions are raised for expected error conditions
- **Error messages:** Messages include actionable context
- **Inheritance:** Exception hierarchy is correct

## File Structure

Tests live in a separate `tests/` directory:

```
tests/
├── __init__.py
├── conftest.py          # Shared fixtures
├── test_smoke.py        # Basic import and version check
└── test_<module>.py     # Tests per module
```

**Naming:** Test files are named `test_<module>.py`. Test functions are named `test_<behavior>[_when_<condition>]`.

## Coverage Target

| Scope | Target | Enforced |
|-------|--------|----------|
| `{{ cookiecutter.project_slug }}/` | 80%+ | Yes |
| `tests/` | — | Not measured |

Coverage is configured in `pyproject.toml` under `[tool.coverage.run]` and `[tool.coverage.report]`.

## Test Naming

```python
# Function-based (used in this template)
def test_version_is_set() -> None: ...
def test_process_raises_on_invalid_input() -> None: ...
def test_process_returns_empty_dict_when_no_data() -> None: ...

# Class-based (use for grouping related tests)
class TestProcessor:
    def test_processes_valid_input(self) -> None: ...
    def test_raises_on_missing_field(self) -> None: ...
    def test_handles_empty_list(self) -> None: ...
```

**Pattern:** `test_<what>_<expected_behavior>[_when_<condition>]`

- Use descriptive names that read as a specification
- Group related tests with classes when a module has many test cases
- Start with the simpler function-based style; upgrade to classes when needed

## Test Data

Use pytest fixtures for reusable test data. Add shared fixtures in `conftest.py`:

```python
@pytest.fixture
def sample_config() -> dict[str, str]:
    """Create a sample configuration dict."""
    return {
        "name": "test",
        "timeout": "30",
        "retries": "3",
    }
```

For more complex scenarios, use factory functions:

```python
def make_item(
    name: str = "test-item",
    status: str = "active",
) -> dict[str, str]:
    return {"name": name, "status": status}
```

## Mocking Strategy

- **Mock external dependencies** — file system, network, databases
- **Mock at boundaries** — when testing a function, mock what it calls, not its internals
- **Use `unittest.mock.MagicMock` and `patch`** — the standard library covers all needs
- **Mock environment variables** with `@patch.dict("os.environ", {...})`
- **Never mock what you own** — if a utility in the module is broken, tests for code that calls it should fail too

## When to Write Tests

### Always test:
- New public functions and classes
- Bug fixes — add a regression test that fails without the fix
- Exception handling paths
- Configuration and initialization logic

### Optional:
- One-line utility functions with trivial logic
- Type-only code (`py.typed`, re-exports)
- Private helper functions called only by tested public functions
