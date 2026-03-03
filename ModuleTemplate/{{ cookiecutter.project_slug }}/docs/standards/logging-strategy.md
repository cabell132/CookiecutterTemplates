# Logging Strategy

How to log effectively in {{ cookiecutter.project_name }} using **wide events** (canonical log lines).

## Core Concept: Wide Events

Instead of scattering log lines throughout a function, emit **one context-rich structured event per operation**. This single event carries everything needed to debug, analyze, and alert — operation name, duration, outcome, error details, and business context.

```
# Bad — scattered, unstructured logs
DEBUG Starting processing
DEBUG Processing item 42
ERROR Failed to process item 42

# Good — one wide event per operation
INFO {"operation": "process_item", "item_id": 42, "duration_ms": 15, "outcome": "error", "error": "validation failed"}
```

**Why this matters:**
- One event per operation = one line to find when debugging
- Structured fields = queryable, filterable, aggregatable
- High cardinality (unique IDs, status codes) + high dimensionality (many fields) = answers to questions you haven't asked yet

References: [Stripe — Canonical Log Lines](https://stripe.com/blog/canonical-log-lines), [Wide Events 101](https://boristane.com/blog/observability-wide-events-101/)

## Current State

The template ships with stdlib `logging` and basic debug/error calls. This section describes the target pattern to evolve toward.

## Wide Event Pattern

The natural boundary for a wide event depends on your module's purpose — one structured event emitted per logical operation.

### Implementation with structlog

```python
import time
from typing import Any

import structlog

logger = structlog.get_logger()


def process(item_id: int, **kwargs: Any) -> dict[str, Any]:
    """Process an item and return the result."""
    start = time.perf_counter()

    # Build the wide event — one dict that accumulates context
    event: dict[str, Any] = {
        "operation": "process",
        "item_id": item_id,
    }

    try:
        result = _do_work(item_id, **kwargs)
        event["outcome"] = "success"
        return result

    except Exception as exc:
        event["outcome"] = "error"
        event["error_type"] = type(exc).__name__
        event["error"] = str(exc)
        raise

    finally:
        event["duration_ms"] = round((time.perf_counter() - start) * 1000, 1)
        logger.info("process_item", **event)
```

### Implementation with stdlib logging

If you prefer to stay with stdlib `logging` (no extra dependency):

```python
import json
import logging
import time
from typing import Any

logger = logging.getLogger(__name__)


def process(item_id: int, **kwargs: Any) -> dict[str, Any]:
    start = time.perf_counter()
    event: dict[str, Any] = {"operation": "process", "item_id": item_id}

    try:
        # ... processing logic ...
        event["outcome"] = "success"
        # ... return result ...
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
| `operation` | str | `"process"` | Name of the operation |
| `duration_ms` | float | `42.3` | Execution time |
| `outcome` | str | `"success"` or `"error"` | Quick filter for dashboards |

## Optional Context Fields

Add these when available:

| Field | When | Example |
|-------|------|---------|
| `error_type` | On error | `"ValueError"` |
| `error` | On error | `"Invalid input"` |
| `item_id` | When processing an entity | `42` |
| `retry_count` | On retry | `2` |

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
| `info` | Every operation wide event (success and error) |
| `error` | Exception auto-logging in `__init__` (already implemented in exceptions) |

Avoid `debug` for request/response tracing — the wide event at `info` level already carries all that context. Avoid `warning` — an event either succeeded or it didn't.

## Anti-Patterns

| Anti-Pattern | Problem | Fix |
|---|---|---|
| Scattered `logger.debug()` per function | Multiple lines to correlate, no single source of truth | One wide event in `finally` block |
| Unstructured strings (`"Processing failed"`) | Not queryable, not filterable | Structured dict with named fields |
| Multiple logger instances | Inconsistent formatting, hard to configure | Single `logger = get_logger()` |
| Logging inside loops | Floods log output, noise | Accumulate in wide event, emit once |
| Missing duration | Can't identify slow operations | `time.perf_counter()` in try/finally |
| Missing outcome field | Can't quickly filter success vs error | Always set `outcome` |

## What to Never Log

- Authentication tokens or API keys
- Passwords or credentials
- PII beyond user identifiers
- Full request/response bodies (use truncation if needed)
- Stack traces in structured event fields (let the exception propagate naturally)

## Consumer Configuration

Library consumers configure logging at their application level. The module should not configure handlers or formatters — only emit events:

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

The module respects whatever configuration the consumer has set up. If no configuration is set, stdlib logging suppresses everything by default (the "last resort" handler).
