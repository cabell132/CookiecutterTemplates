# ADR 001: Initial Tooling Decisions

## Status
Accepted

## Context
Selecting the foundational tools for a modern React + TypeScript application.

## Decisions

### Vite over CRA
Create React App is deprecated. Vite provides native ESM, instant HMR, and is the industry standard.

### Biome over ESLint + Prettier
Single tool replacing both linter and formatter. ~35x faster. Solves formatting-vs-linting conflicts by design. VCS-aware via `biome.json`.

### Zod 4 for validation
Schema-first types via `z.infer`. `safeParse` for forms. `z.toJSONSchema()` for AI tool integration. Single source of truth for types.

### Vitest over Jest
Native ESM support, Vite-compatible, faster execution, compatible API. Built-in coverage via `@vitest/coverage-v8`.

### Tailwind CSS for styling
Utility-first, industry standard.{% if cookiecutter.include_shadcn == "yes" %} Combined with shadcn/ui for accessible component primitives.{% endif %}

### @total-typescript/tsconfig
Strict TypeScript configuration with `moduleResolution: "Bundler"`, `noUncheckedIndexedAccess`, and sensible defaults.

## Consequences
- All formatting/linting through `biome check`
- Types derived from Zod schemas, not duplicated
- 80% coverage threshold enforced in CI
- JSDoc linting via separate ESLint config (Biome doesn't cover JSDoc yet)
