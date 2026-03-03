# Logging Strategy

How to log effectively in the {{ cookiecutter.service_name }} SDK using **wide events** (canonical log lines).

## Core Concept: Wide Events

Instead of scattering log lines throughout a request handler, emit **one context-rich structured event per API call**. This single event carries everything needed to debug, analyze, and alert — method, URL, status, duration, error details, and business context.

```
# Bad — scattered, unstructured logs
DEBUG API Request: method=GET, url=/items/
DEBUG API Response: status_code=200, url=/items/
ERROR API Error: Not found (http_status=404, url=/items/999/)

# Good — one wide event per API call
INFO {"method": "GET", "url": "/items/999/", "status_code": 404, "duration_ms": 42, "outcome": "error", "error": "Not found"}
```

**Why this matters:**
- One event per call = one line to find when debugging
- Structured fields = queryable, filterable, aggregatable
- High cardinality (unique URLs, status codes) + high dimensionality (many fields) = answers to questions you haven't asked yet

References: [Stripe — Canonical Log Lines](https://stripe.com/blog/canonical-log-lines), [Wide Events 101](https://boristane.com/blog/observability-wide-events-101/)

## Current State

The template ships with stdlib `logging` and basic debug/error calls in `session.py` and `exceptions.py`. This section describes the target pattern to evolve toward.

## Wide Event Pattern for an SDK

In an SDK, the natural boundary for a wide event is `session.make_request()` — one structured event emitted per API call.

### Implementation with structlog

```python
import time
from typing import Any

import structlog

logger = structlog.get_logger()


def make_request(
    self,
    method: str,
    endpoint: str,
    **kwargs: Any,
) -> dict[str, Any]:
    """Execute an HTTP request and return parsed response data."""
    url = self.make_url(endpoint)
    start = time.perf_counter()

    # Build the wide event — one dict that accumulates context
    event: dict[str, Any] = {
        "method": method.upper(),
        "url": url,
        "endpoint": endpoint,
    }

    try:
        headers = self._get_request_headers()

        with requests.Session() as session:
            response = session.request(
                method.upper(),
                url,
                headers=headers,
                timeout=self.request_timeout,
                **kwargs,
            )

        event["status_code"] = response.status_code

        if response.status_code >= 400:
            event["outcome"] = "error"
            raise {{ cookiecutter.service_name }}APIError.from_response(response)

        if response.status_code == 204:
            event["outcome"] = "success"
            return {}

        event["outcome"] = "success"
        return self.format_response(response)

    except {{ cookiecutter.service_name }}APIError:
        # Already captured in event, re-raise
        raise

    except Exception as exc:
        event["outcome"] = "error"
        event["error_type"] = type(exc).__name__
        event["error"] = str(exc)
        raise

    finally:
        event["duration_ms"] = round((time.perf_counter() - start) * 1000, 1)
        logger.info("api_call", **event)
```

### Implementation with stdlib logging

If you prefer to stay with stdlib `logging` (no extra dependency):

```python
import json
import time
from typing import Any

logger = logging.getLogger(__name__)


def make_request(self, method: str, endpoint: str, **kwargs: Any) -> dict[str, Any]:
    url = self.make_url(endpoint)
    start = time.perf_counter()
    event: dict[str, Any] = {"method": method.upper(), "url": url}

    try:
        # ... request logic ...
        event["status_code"] = response.status_code
        event["outcome"] = "success" if response.status_code < 400 else "error"
        # ... error handling ...
    except Exception as exc:
        event["outcome"] = "error"
        event["error_type"] = type(exc).__name__
        raise
    finally:
        event["duration_ms"] = round((time.perf_counter() - start) * 1000, 1)
        logger.info(json.dumps(event))
```

## Required Fields

Every wide event should include:

| Field | Type | Example | Purpose |
|-------|------|---------|---------|
| `method` | str | `"GET"` | HTTP method |
| `url` | str | `"/items/123/"` | Full request URL |
| `status_code` | int | `200` | HTTP response status |
| `duration_ms` | float | `42.3` | Round-trip time |
| `outcome` | str | `"success"` or `"error"` | Quick filter for dashboards |

## Optional Context Fields

Add these when available:

| Field | When | Example |
|-------|------|---------|
| `endpoint` | Always | `"/items/{id}/"` (route pattern) |
| `error_type` | On error | `"{{ cookiecutter.service_name }}APIError"` |
| `error` | On error | `"Not found"` |
| `retry_count` | On retry | `2` |
| `response_size` | For debugging payload issues | `1024` |

## Single Logger

Use one logger instance configured at startup and imported everywhere:

```python
# With structlog (recommended)
import structlog
logger = structlog.get_logger()

# With stdlib
import logging
logger = logging.getLogger("{{ cookiecutter.project_slug }}")
```

Do not create multiple logger instances with different names across modules. One logger, one configuration point, consistent output.

## Log Levels

Simplify to two levels:

| Level | When |
|-------|------|
| `info` | Every API call wide event (success and error) |
| `error` | Exception auto-logging in `__init__` (already implemented in `exceptions.py`) |

Avoid `debug` for request/response tracing — the wide event at `info` level already carries all that context. Avoid `warning` — an event either succeeded or it didn't.

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Scattered `logger.debug()` per request | Multiple lines to correlate, no single source of truth | One wide event in `finally` block |
| Unstructured strings (`"API call failed"`) | Not queryable, not filterable | Structured dict with named fields |
| Multiple logger instances | Inconsistent formatting, hard to configure | Single `logger = get_logger()` |
| Logging inside loops | Floods log output, noise | Accumulate in wide event, emit once |
| Missing duration | Can't identify slow calls | `time.perf_counter()` in try/finally |
| Missing outcome field | Can't quickly filter success vs error | Always set `outcome` |

## What to Never Log

- Authentication tokens or API keys
- Passwords or credentials
- PII beyond user identifiers
- Full request/response bodies (use truncation if needed)
- Stack traces in structured event fields (let the exception propagate naturally)

## SDK Consumer Configuration

SDK consumers configure logging at their application level. The SDK should not configure handlers or formatters — only emit events:

```python
# Consumer configures once at app startup
import structlog

structlog.configure(
    processors=[
        structlog.processors.TimeStamper(fmt="iso"),
        structlog.processors.JSONRenderer(),
    ],
)

# Or with stdlib
import logging

logging.basicConfig(
    level=logging.INFO,
    format="%(message)s",
)
```

The SDK respects whatever configuration the consumer has set up. If no configuration is set, stdlib logging suppresses everything by default (the "last resort" handler).
