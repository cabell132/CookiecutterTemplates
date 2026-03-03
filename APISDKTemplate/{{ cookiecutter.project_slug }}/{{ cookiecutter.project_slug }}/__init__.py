"""{{ cookiecutter.module_description }}"""

from __future__ import annotations

from {{ cookiecutter.project_slug }}.client import {{ cookiecutter.service_name }}Client
from {{ cookiecutter.project_slug }}.session import {{ cookiecutter.service_name.upper() }}_API_URL

__all__ = ["{{ cookiecutter.service_name.upper() }}_API_URL", "{{ cookiecutter.service_name }}Client"]

__author__ = """{{ cookiecutter.full_name }}"""
__email__ = "{{ cookiecutter.email }}"
__version__ = "{{ cookiecutter.initial_version }}"
