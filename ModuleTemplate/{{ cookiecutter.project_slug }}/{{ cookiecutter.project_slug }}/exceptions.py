"""Exceptions for {{ cookiecutter.project_name }}."""

from __future__ import annotations


class {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error(Exception):
    """Base exception for {{ cookiecutter.project_name }}."""


class {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}ValueError(
    {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error,
    ValueError,
):
    """Invalid input or configuration."""


class {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}RuntimeError(
    {{ cookiecutter.project_slug.replace('_', ' ') | title | replace(' ', '') }}Error,
    RuntimeError,
):
    """Runtime / operational failure."""
