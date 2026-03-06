# Testing Strategy

## Testing Pyramid

### Unit Tests (Vitest)
- Utility functions, hooks, schemas
- Fast, isolated, no DOM

### Component Tests (React Testing Library)
- Render + interact + assert
- Use `userEvent` over `fireEvent`
- Custom render wrapper in `src/test/utils.tsx`
- Test behavior, not implementation

### E2E Tests (Playwright)
- Critical user flows only
- Run in CI, not on every commit

## What to Test
- API contracts and response handling
- Shared utility functions
- Complex business logic
- Error states and edge cases
- Accessibility (roles, labels)

## What NOT to Test
- What TypeScript already guarantees (types, interfaces)
- Simple prop passing
- Third-party library internals
- CSS/styling details

## Coverage
- 80% threshold enforced in CI (lines, branches, functions, statements)
- Exclude: test files, setup files, `main.tsx`
