"""{{ cookiecutter.service_name }} authentication."""

from {{ cookiecutter.project_slug }}.auth.base import {{ cookiecutter.service_name }}AuthBase
from {{ cookiecutter.project_slug }}.auth.oauth import {{ cookiecutter.service_name }}OAuth

__all__ = ["{{ cookiecutter.service_name }}AuthBase", "{{ cookiecutter.service_name }}OAuth"]
