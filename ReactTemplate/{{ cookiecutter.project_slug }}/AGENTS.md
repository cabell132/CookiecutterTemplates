# Agent Instructions

## Stack
React 19 + TypeScript (strict) + Vite + Biome + Vitest + Tailwind + Zod 4

## Quality Gates
```bash
{{ cookiecutter.node_package_manager }} run typecheck    # tsc --noEmit
{{ cookiecutter.node_package_manager }} run lint         # biome check
{{ cookiecutter.node_package_manager }} run test         # vitest run
{{ cookiecutter.node_package_manager }} run jsdoc        # eslint-plugin-jsdoc
{{ cookiecutter.node_package_manager }} run check        # all gates combined
```

## Conventions
- Feature-based structure: `src/features/<name>/{components,hooks,schemas,__tests__}/`
- Types in `.ts` files, NEVER `.d.ts` (those are for global augmentation only)
- Zod schemas are the source of truth for types (`z.infer<typeof schema>`)
- `safeParse` in UI code, never `parse`
- Return types on exported functions
- `as const` for config objects
- Discriminated unions for state modeling
- Be extremely concise

### File Structure
- One component per file — plan splits before writing
- Keep files under 300 lines — extract hooks, utils, and sub-components early

### Imports
- Always add imports and their usage in the same edit operation
- Use `type` imports for type-only references (`import type { Foo } from ...`)

## Commit Attribution
AI commits MUST include:
```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Agent Notes
If you encounter something surprising or confusing in this project,
note it here to help future agents.
