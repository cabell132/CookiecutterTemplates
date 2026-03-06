# Copilot Instructions for {{ cookiecutter.project_name }}

## Stack
React 19 + TypeScript (strict) + Vite + Biome + Vitest + Tailwind + Zod 4

## Conventions
- Feature-based structure: `src/features/<name>/{components,hooks,schemas,__tests__}/`
- Types in `.ts` files, NEVER `.d.ts`
- Zod schemas are the source of truth for types (`z.infer<typeof schema>`)
- `safeParse` in UI code, never `parse`
- Return types on exported functions
- `as const` for config objects
- Discriminated unions for state modeling
- Error hierarchy: `AppError` > `ValidationError` | `RuntimeError`
- Test with RTL + userEvent, not implementation details
