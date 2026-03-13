# Agent Instructions

## Code Style

### File Structure
- Max 300 code lines per file (docstrings, comments, blanks excluded; 500 hard cap) — plan splits before writing
- One class per file (unless in a `models/` directory or file is under 50 lines total)
- `__init__.py` contains only imports, `__all__`, and `__version__` — no logic, no functions, no classes

### Docstrings (Google style, pydoclint-enforced)
- Every public function and method needs a docstring
- Include `Args:`, `Returns:`, `Raises:` sections only when applicable
- If a function returns `None` implicitly, omit the `Returns:` section entirely
- The return type annotation must match the docstring `Returns:` type exactly (DOC201/DOC203)
- Skip docstrings on test functions and `__init__` methods that just call `super()`

### Functions
- Max 20 statements per function (PLR0915) — extract helpers early
- No blind `except Exception` (BLE001) — catch specific exceptions
- Max 5 parameters (PLR0913) — group into a dataclass or config object
- No imports inside functions (PLC0415) unless conditionally needed

### Imports
- Always add imports and their usage in the same edit operation
- Use `from __future__ import annotations` for forward references
- Use `if TYPE_CHECKING:` blocks for imports only needed by the type checker

## Commit Attribution
AI commits MUST include:
```
Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
```

## Agent Notes
If you encounter something surprising or confusing in this project,
note it here to help future agents.
