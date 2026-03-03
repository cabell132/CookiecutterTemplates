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
uv run poe test
```

## Usage

```python
from {{ cookiecutter.project_slug }} import {{ cookiecutter.service_name }}Client
{% if cookiecutter.auth_mode == "api_key" %}
# Auth via {{ cookiecutter.auth_env_var_name }} environment variable
client = {{ cookiecutter.service_name }}Client()
{% elif cookiecutter.auth_mode == "bearer_token" %}
client = {{ cookiecutter.service_name }}Client(auth="your-token")
{% elif cookiecutter.auth_mode == "oauth" %}
from {{ cookiecutter.project_slug }}.auth import {{ cookiecutter.service_name }}OAuth
from {{ cookiecutter.project_slug }}.cache_handler import CacheFileHandler

client = {{ cookiecutter.service_name }}Client(
    auth_manager={{ cookiecutter.service_name }}OAuth(cache_handler=CacheFileHandler()),
)
{% endif %}
# List items with pagination
items = client.items.search(page=1, per_page=25)
print(items.count)
print(items.response_url)

for item in items.results:
    print(item.name)

# Get a single item
item = client.items.get(id=42)
print(item.name)
```
