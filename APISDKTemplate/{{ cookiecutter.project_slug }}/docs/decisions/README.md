# Architecture Decision Records

This directory captures key architectural decisions for the project. Each ADR explains **why** a technology or approach was chosen, not just what was chosen.

## Index

| # | Decision | Status |
|---|----------|--------|
| [001](001-initial-tooling.md) | Python tooling choices (uv, ruff, ty, pydoclint, poe) | Accepted |

## Template

When adding a new ADR, copy this template:

```markdown
# ADR-NNN: Title

## Status

Accepted | Superseded by [ADR-NNN](NNN-title.md) | Deprecated

## Context

What is the issue we're facing? What are the forces at play?

## Decision

What is the change we're making?

## Consequences

What becomes easier or harder because of this decision?
```

**Naming:** `NNN-short-title.md` (zero-padded three-digit number, kebab-case title).

**Rules:**
- ADRs are immutable once accepted. If a decision changes, write a new ADR that supersedes the old one.
- Keep ADRs short. A few paragraphs per section is enough.
- Focus on the "why" — the "what" is usually obvious from the codebase.
