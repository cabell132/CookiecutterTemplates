"""Allow running the package with ``python -m {{ cookiecutter.project_slug }}``."""

from __future__ import annotations
{% if cookiecutter.include_cli == "typer" %}
from {{ cookiecutter.project_slug }}.cli import app

app()
{% endif %}
