from __future__ import annotations

from {{ cookiecutter.project_slug }} import (
    __version__,
    {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error,
)


def test_version() -> None:
    assert __version__


def test_base_exception_importable() -> None:
    assert issubclass({{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error, Exception)
