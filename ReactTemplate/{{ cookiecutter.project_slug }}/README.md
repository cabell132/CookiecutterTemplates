# {{ cookiecutter.project_name }}

{{ cookiecutter.description }}

## Getting Started

```bash
{{ cookiecutter.node_package_manager }}{% if cookiecutter.node_package_manager == "npm" %} run{% endif %} dev
```

## Scripts

| Command | Description |
|---------|-------------|
| `{{ cookiecutter.node_package_manager }} run dev` | Start development server |
| `{{ cookiecutter.node_package_manager }} run build` | Type check + production build |
| `{{ cookiecutter.node_package_manager }} run typecheck` | TypeScript type checking |
| `{{ cookiecutter.node_package_manager }} run lint` | Biome linting |
| `{{ cookiecutter.node_package_manager }} run lint:fix` | Auto-fix lint issues |
| `{{ cookiecutter.node_package_manager }} run test` | Run tests |
| `{{ cookiecutter.node_package_manager }} run test:coverage` | Tests with coverage report |
| `{{ cookiecutter.node_package_manager }} run check` | Full quality gate |

## Project Structure

```
src/
├── app/          # App shell (App.tsx, providers, router)
├── features/     # Feature modules (co-located logic+UI+tests)
├── components/   # Shared UI components
├── hooks/        # Shared hooks
├── lib/          # Utilities, API client, config
├── types/        # Shared types
└── test/         # Test setup & utilities
```

## Tech Stack

- **Build:** Vite
- **Language:** TypeScript (strict)
- **Linter/Formatter:** Biome
- **Validation:** Zod 4
- **Styling:** Tailwind CSS
- **Testing:** Vitest + React Testing Library
