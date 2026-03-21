# package.json Merge Rules

## Strategy

Key-level replacement within the JSON object. Read both files as JSON, merge specific keys, write back with consistent formatting.

## Process

1. Read the project's `package.json` as JSON
2. Read the template's `package.json` (rendered with resolved variables) as JSON
3. Apply merge rules per key
4. Write back with 2-space indent and trailing newline

## Keys to FULL REPLACE

These keys are template-owned. Replace them entirely with the template version:

### `scripts`

The entire `scripts` object is replaced with the template's version. This ensures build/lint/test commands stay consistent.

### `lint-staged`

Only if `enable_precommit` is "yes". Replace the entire `lint-staged` object with the template version.

## Keys to UNION MERGE

### `devDependencies`

- Add any template devDependencies that are missing from the project
- Keep all existing project devDependencies (even if not in template)
- If a dependency exists in both, keep the project's version (don't downgrade)
- Sort keys alphabetically after merging

## Keys to NEVER MODIFY

- `name` — project identity
- `version` — project version
- `description` — project description
- `author` — project author
- `license` — project license
- `dependencies` — project runtime dependencies (user adds their own)
- `type` — module type
- `private` — publish flag
- Any other keys not listed above

## Implementation Notes

- Use `JSON.parse` / `JSON.stringify` equivalent (read as JSON, write as JSON)
- Preserve any extra top-level keys the project has added
- Template `package.json` may contain `{{ cookiecutter.project_slug }}` in the `name` field — this should already be rendered before merging, but the `name` field is never overwritten anyway
- After merging, ensure the output is valid JSON with 2-space indentation and a trailing newline
