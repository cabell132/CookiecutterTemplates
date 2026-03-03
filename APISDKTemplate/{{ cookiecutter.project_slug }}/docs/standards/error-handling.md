# Error Handling Strategy

How to handle errors consistently in the {{ cookiecutter.service_name }} SDK.

## Guiding Principles

1. **Fail fast** — Detect errors early, raise immediately. Don't return ambiguous values.
2. **Structured errors** — Every exception carries context (HTTP status, URL, message). No bare strings.
3. **Never expose internals** — Stack traces, credentials, and internal state stay server-side.
4. **Log with context** — Exceptions auto-log on construction with message, status code, and URL.

## Exception Hierarchy

```
{{ cookiecutter.service_name }}BaseError
├── {{ cookiecutter.service_name }}APIError      # API returned an error response
└── {{ cookiecutter.service_name }}AuthError      # Authentication/authorization failure
```

Defined in `{{ cookiecutter.project_slug }}/exceptions.py`.

## Error Code Mapping

| HTTP Status | Exception | Meaning | Example |
|-------------|-----------|---------|---------|
| 400 | `{{ cookiecutter.service_name }}APIError` | Invalid request | Bad query parameters |
| 401 | `{{ cookiecutter.service_name }}AuthError` | Not authenticated | Missing or expired token |
| 403 | `{{ cookiecutter.service_name }}AuthError` | Forbidden | Insufficient permissions |
| 404 | `{{ cookiecutter.service_name }}APIError` | Not found | Resource does not exist |
| 409 | `{{ cookiecutter.service_name }}APIError` | Conflict | Duplicate or concurrent edit |
| 429 | `{{ cookiecutter.service_name }}APIError` | Rate limited | Too many requests |
| 500+ | `{{ cookiecutter.service_name }}APIError` | Server error | Unexpected upstream failure |

## Raising Exceptions (SDK Internals)

The session layer raises automatically from HTTP error responses:

```python
# session.py — this happens automatically in make_request()
if response.status_code >= 400:
    raise {{ cookiecutter.service_name }}APIError.from_response(response)
```

The `from_response()` factory extracts the message from the JSON body (checking `detail` then `message` fields) and attaches the URL and status code:

```python
from {{ cookiecutter.project_slug }}.exceptions import {{ cookiecutter.service_name }}APIError

# Manual raise when needed (e.g., validation before making a request)
raise {{ cookiecutter.service_name }}APIError(
    message="Item ID must be a positive integer",
    url="/items/",
    http_status=400,
)
```

For authentication failures, raise `{{ cookiecutter.service_name }}AuthError` directly:

```python
from {{ cookiecutter.project_slug }}.exceptions import {{ cookiecutter.service_name }}AuthError

raise {{ cookiecutter.service_name }}AuthError(
    message="Token expired",
    error="token_expired",
)
```

### Rules

- **Never catch and swallow** — Let exceptions propagate to the caller. The SDK consumer decides how to handle them.
- **Use `from_response()`** — Don't manually parse error responses. The factory handles JSON and non-JSON bodies.
- **Auth checks first** — Validate credentials before making HTTP requests.

## SDK Consumer Patterns

Callers of the SDK should catch specific exception types:

```python
from {{ cookiecutter.project_slug }}.exceptions import (
    {{ cookiecutter.service_name }}APIError,
    {{ cookiecutter.service_name }}AuthError,
    {{ cookiecutter.service_name }}BaseError,
)

try:
    item = client.items.get(item_id=42)
except {{ cookiecutter.service_name }}AuthError:
    # Re-authenticate or prompt for new credentials
    ...
except {{ cookiecutter.service_name }}APIError as e:
    if e.http_status == 404:
        # Handle not found
        ...
    elif e.http_status == 429:
        # Back off and retry
        ...
    else:
        # Log and re-raise for unexpected errors
        raise
```

Catch `{{ cookiecutter.service_name }}BaseError` as a catch-all only when you want to handle any SDK error generically:

```python
try:
    items = client.items.search(query="test")
except {{ cookiecutter.service_name }}BaseError:
    # Fallback for any SDK error
    ...
```

## Logging

Exceptions auto-log on construction via `logging.getLogger(__name__)`:

- `{{ cookiecutter.service_name }}APIError.__init__` logs at `ERROR` level with message, status code, and URL
- `{{ cookiecutter.service_name }}AuthError.__init__` logs at `ERROR` level with message and error code
- The session layer logs requests and responses at `DEBUG` level

SDK consumers should **not** re-log SDK exceptions — they are already logged.

## What to Never Log

- Authentication tokens or API keys
- Passwords or credentials
- PII beyond user ID (no emails, names, or addresses)
- Full request/response bodies from external APIs
- Stack traces in user-facing error messages
