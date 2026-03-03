"""Base resource class for {{ cookiecutter.service_name }} API."""

from __future__ import annotations

from {{ cookiecutter.project_slug }}.session import {{ cookiecutter.service_name }}Session
from {{ cookiecutter.project_slug }}.utils import add_scheme_to_url


class Base:
    """Base class for {{ cookiecutter.service_name }} API resources."""

    def __init__(self, session: {{ cookiecutter.service_name }}Session) -> None:
        self.session = session

    @staticmethod
    def fix_pagination_urls(data: dict, scheme: str = "https") -> None:  # type: ignore[type-arg]
        """Ensure next/previous pagination URLs have a scheme prefix."""
        for key in ("next", "previous"):
            if data.get(key) is not None:
                data[key] = add_scheme_to_url(data[key], scheme)
