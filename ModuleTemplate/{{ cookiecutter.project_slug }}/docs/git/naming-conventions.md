# Git Naming Conventions

## Branch Names

### Format
```
<ISSUE-KEY>-<short-description>
```

If using Jira or another issue tracker, include the issue key at the start for automatic linking. The issue key **must use capital letters** (e.g., `PROJ-123`, not `proj-123`).

### Examples
```
PROJ-123-add-oauth-login
PROJ-456-fix-payment-timeout
PROJ-789-update-dependencies
```

### With Type Prefix (Optional)
```
feature/PROJ-123-add-oauth-login
fix/PROJ-456-payment-timeout
hotfix/PROJ-789-critical-crash
```

### Type Prefixes
| Type | Purpose |
|------|---------|
| `feature` | New functionality |
| `fix` | Bug fixes |
| `hotfix` | Urgent production fixes |
| `chore` | Maintenance, deps, config |
| `docs` | Documentation only |
| `refactor` | Code restructuring |
| `test` | Test additions/fixes |

### Rules
- Issue key at the start (or after type prefix)
- Use capital letters for issue key: `PROJ-123`
- Use lowercase for description
- Use hyphens (`-`) as word separators
- Keep descriptions short (2-4 words)

---

## Commit Messages

### Format
```
<ISSUE-KEY> <type>(<scope>): <description>

[optional body]

[optional footer]
```

Place the issue key at the **beginning** of the commit message for automatic issue-tracker linking.

### Types
| Type | When to Use |
|------|-------------|
| `feat` | New feature for users |
| `fix` | Bug fix for users |
| `docs` | Documentation changes |
| `style` | Formatting, whitespace (no code change) |
| `refactor` | Code restructuring (no behavior change) |
| `perf` | Performance improvements |
| `test` | Adding/fixing tests |
| `chore` | Build, deps, tooling |
| `ci` | CI/CD configuration |
| `revert` | Reverting previous commit |

### Examples

**Simple:**
```
PROJ-123 feat(auth): add password reset flow
```

**With body:**
```
PROJ-456 fix(api): handle null response from payment gateway

The payment gateway returns null instead of an error object
when the service is unavailable. Added null check to prevent
crash and return appropriate error message.
```

**Breaking change:**
```
PROJ-789 feat(api)!: change authentication endpoint response format

BREAKING CHANGE: The /auth/login endpoint now returns
{ token, user } instead of { accessToken, refreshToken, userData }
```

### Description Rules
- Use imperative mood: "add" not "added" or "adds"
- No capitalization at start of description
- No period at end
- Max 50 characters for subject line
- Wrap body at 72 characters

---

## Pull Request Titles

### Format
```
<ISSUE-KEY> <type>(<scope>): <description>
```

Include the issue key in the PR title for issue-tracker linking.

### Examples
```
PROJ-123 feat(auth): add OAuth2 support
PROJ-456 fix(session): resolve timeout on large payloads
PROJ-789 docs(api): add rate limiting documentation
```

---

## Tags / Versions

### Format (Semantic Versioning)
```
v<major>.<minor>.<patch>[-<prerelease>]
```

### Version Components
| Component | When to Increment |
|-----------|-------------------|
| `major` | Breaking/incompatible changes |
| `minor` | New features (backward compatible) |
| `patch` | Bug fixes (backward compatible) |

### Examples
```
v1.0.0        # Initial stable release
v1.1.0        # New feature added
v1.1.1        # Bug fix
v2.0.0        # Breaking change
v2.0.0-beta.1 # Pre-release
```

---

## Quick Reference

```
Branch:  PROJ-123-short-description
         feature/PROJ-123-short-description

Commit:  PROJ-123 feat(scope): imperative description

PR:      PROJ-123 feat(scope): imperative description

Tag:     v1.2.3
```

### Key Rules
- Issue keys must be **UPPERCASE**: `PROJ-123` not `proj-123`
- Issue key goes at the **start** of commits and PR titles
- Use **hyphens** for word separation in branch names
- Use **imperative mood** for descriptions: "add" not "added"
