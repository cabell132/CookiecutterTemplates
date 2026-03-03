"""{{ cookiecutter.module_description }}"""

from __future__ import annotations

from {{ cookiecutter.project_slug }}.exceptions import (
    {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error,
    {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}RuntimeError,
    {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}ValueError,
)

__all__ = [
    "__version__",
    "{{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error",
    "{{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}RuntimeError",
    "{{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}ValueError",
]

__version__ = "{{ cookiecutter.initial_version }}"
