# Logging Strategy

## Approach
Structured logging using native console methods with consistent formatting.

## Levels
- `console.error` — Errors requiring attention
- `console.warn` — Degraded functionality, fallback behavior
- `console.info` — Key lifecycle events (app init, auth state changes)
- `console.debug` — Development-only diagnostic info

## Patterns

### API Calls (Wide Events)
Log request + response as a single structured event:
```typescript
console.info("api_call", { url, method, status, durationMs });
```

### Error Reporting
Integrate with error boundary `componentDidCatch` for centralized error reporting.

### Production
Consider stripping `console.debug` in production via Vite's `esbuild.drop` config. Integrate a structured error reporting service for production error tracking.
