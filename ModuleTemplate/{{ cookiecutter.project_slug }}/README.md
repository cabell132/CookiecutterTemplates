# {{ cookiecutter.project_name }}

{{ cookiecutter.module_description }}

## Requirements

- Python {{ cookiecutter.python_version }}+
- [uv](https://github.com/astral-sh/uv)

## Getting Started

```bash
uv sync
{% if cookiecutter.enable_precommit.lower().startswith('y') -%}
# optional: install pre-commit hooks
uv tool run pre-commit install
{% endif -%}
```

## Tasks

This project uses [Poe the Poet](https://github.com/nat-n/poethepoet) via uv.

```bash
uv run poe lint
uv run poe format
uv run poe typecheck
uv run poe doclint
uv run poe test
```
{% if cookiecutter.include_cli == "typer" %}
## CLI

```bash
uv run {{ cookiecutter.project_slug.replace('_', '-') }} --help
uv run {{ cookiecutter.project_slug.replace('_', '-') }} version
```
{% endif %}
{%- if cookiecutter.include_docs == "mkdocs" %}
## Docs

```bash
uv run poe docs
```
{% endif %}
