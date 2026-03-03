# Testing Strategy

When, what, and how to test the {{ cookiecutter.service_name }} SDK.

## Testing Pyramid

```
        ┌─────────┐
        │  E2E    │  10% — Full API round-trips (optional)
        ├─────────┤
        │ Integr. │  20% — Component interactions, mocked HTTP
        ├─────────┤
        │  Unit   │  70% — Functions, classes, isolated logic
        └─────────┘
```

Invest most effort in fast, isolated unit tests. Use integration tests for component interactions. E2E tests against a live API are optional and should be run separately.

## Framework

| Layer | Tool | Location |
|-------|------|----------|
| Unit | pytest | `tests/unit/` |
| Integration | pytest | `tests/integration/` |
| Coverage | pytest-cov | Config in `pyproject.toml` |

Run tests with:
```
uv run poe test
```

## What to Test

### Session layer (`session.py`) — Required

The HTTP communication layer. Correctness here prevents all downstream bugs.

- **Request construction:** Headers built correctly for the auth mode, URLs assembled properly
- **Error handling:** `{{ cookiecutter.service_name }}APIError.from_response()` raised for 4xx/5xx responses
- **Response parsing:** JSON parsed, `response_url` injected, 204 returns empty dict

### Client (`client.py`) — Required

- **Resource initialization:** `client.items` exists and is the correct type
- **Session creation:** Session configured with correct auth credentials

### Resource classes (`items.py`, etc.) — Required

- **Endpoint mapping:** Methods call the correct HTTP method and path
- **Pagination:** URL fixing for relative pagination links
- **Parameters:** Query params and request bodies passed correctly

### Exception hierarchy (`exceptions.py`) — Required

- **Inheritance:** `{{ cookiecutter.service_name }}APIError` and `{{ cookiecutter.service_name }}AuthError` are subclasses of `{{ cookiecutter.service_name }}BaseError`
- **Factory method:** `from_response()` handles JSON bodies, non-JSON bodies, and missing fields
- **String representation:** `__str__` includes status code, URL, and message

### Models (`models.py`) — Required

- **Validation:** Pydantic models accept valid data and reject invalid data
- **Serialization:** Models round-trip through `.model_dump()` and `.model_validate()`

### Auth (`auth/`) — If using OAuth

- **Token management:** Access tokens retrieved and cached correctly
- **Token refresh:** Expired tokens trigger refresh flow
- **Cache handlers:** File and memory cache handlers store and retrieve tokens

## File Structure

Tests live in a separate `tests/` directory, organized by test type:

```
tests/
├── __init__.py
├── conftest.py              # Shared fixtures (mock_response, mock_session)
├── unit/
│   ├── __init__.py
│   ├── test_client.py
│   └── test_exceptions.py
└── integration/
    └── __init__.py
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
def test_client_has_items_resource() -> None: ...
def test_api_error_from_response() -> None: ...
def test_api_error_from_response_non_json() -> None: ...

# Class-based (use for grouping related tests)
class TestAPIError:
    def test_from_response_extracts_detail(self) -> None: ...
    def test_from_response_falls_back_to_reason(self) -> None: ...
    def test_str_includes_status_and_url(self) -> None: ...
```

**Pattern:** `test_<what>_<expected_behavior>[_when_<condition>]`

- Use descriptive names that read as a specification
- Group related tests with classes when a module has many test cases
- Start with the simpler function-based style; upgrade to classes when needed

## Test Data

Use pytest fixtures for reusable test data. The template includes shared fixtures in `conftest.py`:

```python
@pytest.fixture
def mock_response() -> MagicMock:
    """Create a mock requests.Response."""
    response = MagicMock()
    response.status_code = 200
    response.url = "https://api.example.com/v1/items/"
    response.reason = "OK"
    response.json.return_value = {
        "id": 1,
        "name": "Test Item",
        "slug": "test-item",
    }
    return response
```

For more complex scenarios, use factory functions:

```python
def make_error_response(
    status_code: int = 400,
    detail: str = "Bad request",
) -> MagicMock:
    response = MagicMock()
    response.status_code = status_code
    response.url = "https://api.example.com/v1/items/"
    response.reason = "Bad Request"
    response.json.return_value = {"detail": detail}
    return response
```

## Mocking Strategy

- **Mock `requests.Session`** for unit tests — never make real HTTP calls
- **Mock at the session boundary** — when testing resource classes, mock `session.make_request()`
- **Use `unittest.mock.MagicMock` and `patch`** — the standard library covers all needs
- **Mock environment variables** with `@patch.dict("os.environ", {...})` for API key auth
- **Never mock what you own** — if a utility in the SDK is broken, tests for code that calls it should fail too

### Integration tests

For `tests/integration/`, consider:
- **`responses` library** — mock HTTP at the `requests` adapter level for realistic round-trips
- **`pytest-httpserver`** — spin up a local HTTP server for true integration tests
- **VCR/cassettes** — record and replay real API responses for reproducible tests

## When to Write Tests

### Always test:
- New resource classes and methods
- Bug fixes — add a regression test that fails without the fix
- Exception handling paths
- Authentication flows

### Optional:
- Pydantic models with no custom validators (Pydantic's own tests cover this)
- One-line utility functions with trivial logic
- Type-only code (`py.typed`, re-exports)
