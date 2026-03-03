# Error Handling Strategy

How to handle errors consistently in {{ cookiecutter.project_name }}.

## Guiding Principles

1. **Fail fast** — Detect errors early, raise immediately. Don't return ambiguous values.
2. **Structured errors** — Every exception carries context (message, relevant data). No bare strings.
3. **Never expose internals** — Stack traces, credentials, and internal state stay server-side.
4. **Log with context** — Exceptions auto-log on construction with relevant details.

## Exception Hierarchy

Define a module-level base exception and specific subclasses:

```
{{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error          # Base error for the module
├── {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}ValueError   # Invalid input or configuration
└── {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}RuntimeError # Runtime / operational failure
```

Define exceptions in `{{ cookiecutter.project_slug }}/exceptions.py`.

## Raising Exceptions

```python
from {{ cookiecutter.project_slug }}.exceptions import {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}ValueError

raise {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}ValueError(
    "Configuration key 'timeout' must be a positive integer",
)
```

### Rules

- **Never catch and swallow** — Let exceptions propagate to the caller. The consumer decides how to handle them.
- **Specific over generic** — Raise the most specific exception type available.
- **Message quality** — Include what went wrong and what the caller can do about it.

## Consumer Patterns

Callers should catch specific exception types:

```python
from {{ cookiecutter.project_slug }}.exceptions import (
    {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error,
    {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}ValueError,
)

try:
    result = do_something()
except {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}ValueError as e:
    # Handle invalid input
    ...
except {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error:
    # Catch-all for any module error
    ...
```

## Logging

Exceptions should log on construction via `logging.getLogger(__name__)`:

- Log at `ERROR` level with message and relevant context
- Consumers should **not** re-log module exceptions — they are already logged

## What to Never Log

- Authentication tokens or API keys
- Passwords or credentials
- PII beyond user ID (no emails, names, or addresses)
- Full request/response bodies from external APIs
- Stack traces in user-facing error messages
