# Error Handling Strategy

## Error Hierarchy
- `AppError` — Base class with `code` discriminant
- `ValidationError` — User input, form data, Zod parse failures
- `RuntimeError` — Network failures, unexpected state

## Patterns

### Zod Validation
Always use `safeParse` in UI code:
```typescript
const result = schema.safeParse(data);
if (!result.success) {
  // Handle validation error
}
```

### Error Boundaries
Wrap route segments with `<ErrorBoundary>` to catch render errors gracefully.

### TanStack Query
Use `onError` callbacks and `error` state from `useQuery`/`useMutation` for async errors.

### API Client
The `apiClient` wrapper in `src/lib/api-client.ts` throws `RuntimeError` on non-OK responses.
