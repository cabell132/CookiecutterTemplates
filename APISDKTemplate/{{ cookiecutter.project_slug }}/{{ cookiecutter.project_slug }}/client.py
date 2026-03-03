"""{{ cookiecutter.service_name }} API client."""

from __future__ import annotations
{% if cookiecutter.auth_mode == "oauth" %}
from {{ cookiecutter.project_slug }}.auth import {{ cookiecutter.service_name }}AuthBase, {{ cookiecutter.service_name }}OAuth
from {{ cookiecutter.project_slug }}.cache_handler import CacheHandler
{%- endif %}
from {{ cookiecutter.project_slug }}.items import Items
from {{ cookiecutter.project_slug }}.session import {{ cookiecutter.service_name }}Session


class {{ cookiecutter.service_name }}Client:
    """A class that represents a {{ cookiecutter.service_name }} API client."""
{% if cookiecutter.auth_mode == "api_key" %}
    def __init__(self) -> None:
        self.session = {{ cookiecutter.service_name }}Session()

        self.items = Items(session=self.session)
{% elif cookiecutter.auth_mode == "bearer_token" %}
    def __init__(
        self,
        auth: str | None = None,
    ) -> None:
        self.session = {{ cookiecutter.service_name }}Session(auth=auth)

        self.items = Items(session=self.session)
{% elif cookiecutter.auth_mode == "oauth" %}
    def __init__(
        self,
        auth: str | None = None,
        auth_manager: {{ cookiecutter.service_name }}AuthBase | None = None,
        cache_handler: CacheHandler | None = None,
    ) -> None:
        self.session = {{ cookiecutter.service_name }}Session(
            auth=auth,
            auth_manager=auth_manager,
            oauth_manager={{ cookiecutter.service_name }}OAuth(cache_handler=cache_handler),
        )

        self.items = Items(session=self.session)
{% endif %}
