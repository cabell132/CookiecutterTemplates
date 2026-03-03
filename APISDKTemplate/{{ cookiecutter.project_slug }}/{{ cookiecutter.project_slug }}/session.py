"""{{ cookiecutter.service_name }} API session — handles all HTTP communication."""

from __future__ import annotations

import logging
{% if cookiecutter.auth_mode == "api_key" -%}
import os
{% endif -%}
from typing import Any
from urllib.parse import urlencode

import requests
{% if cookiecutter.auth_mode == "api_key" -%}
from dotenv import load_dotenv
{% endif %}
{%- if cookiecutter.auth_mode == "oauth" %}
from {{ cookiecutter.project_slug }}.auth import {{ cookiecutter.service_name }}AuthBase
{%- endif %}
from {{ cookiecutter.project_slug }}.exceptions import {{ cookiecutter.service_name }}APIError

logger = logging.getLogger(__name__)
{% if cookiecutter.auth_mode == "api_key" %}
load_dotenv()
{% endif %}
{{ cookiecutter.service_name.upper() }}_API_URL = "{{ cookiecutter.api_base_url }}"


class {{ cookiecutter.service_name }}Session:
    """Manages HTTP requests to the {{ cookiecutter.service_name }} API."""
{% if cookiecutter.auth_mode == "api_key" %}
    def __init__(
        self,
        request_timeout: int = 10,
    ) -> None:
        self.api_key = os.environ["{{ cookiecutter.auth_env_var_name }}"]
        self.prefix = {{ cookiecutter.service_name.upper() }}_API_URL
        self.request_timeout = request_timeout
{% elif cookiecutter.auth_mode == "bearer_token" %}
    def __init__(
        self,
        auth: str | None = None,
        request_timeout: int = 10,
    ) -> None:
        self._auth = auth
        self.prefix = {{ cookiecutter.service_name.upper() }}_API_URL
        self.request_timeout = request_timeout
{% elif cookiecutter.auth_mode == "oauth" %}
    def __init__(
        self,
        auth: str | None = None,
        auth_manager: {{ cookiecutter.service_name }}AuthBase | None = None,
        oauth_manager: {{ cookiecutter.service_name }}AuthBase | None = None,
        request_timeout: int = 10,
    ) -> None:
        self._auth = auth
        self.auth_manager = auth_manager
        self.oauth_manager = oauth_manager
        self.prefix = {{ cookiecutter.service_name.upper() }}_API_URL
        self.request_timeout = request_timeout
{% endif %}
    def _get_request_headers(self) -> dict[str, str]:
        """Build authorization and user-agent headers."""
{% if cookiecutter.auth_mode == "api_key" %}
        return {"api-key": self.api_key}
{% elif cookiecutter.auth_mode == "bearer_token" %}
        return {"Authorization": f"Bearer {self._auth}"}
{% elif cookiecutter.auth_mode == "oauth" %}
        if self._auth:
            token = self._auth
        elif self.auth_manager:
            token = self.auth_manager.get_access_token()
        elif self.oauth_manager:
            token = self.oauth_manager.get_access_token()
        else:
            msg = "No auth token, auth_manager, or oauth_manager provided."
            raise {{ cookiecutter.service_name }}APIError(message=msg, url="", http_status=None)
        return {"Authorization": f"Bearer {token}"}
{% endif %}
    def make_url(self, endpoint: str, query: dict[str, str] | None = None) -> str:
        """Build the full request URL from a relative endpoint."""
        if endpoint.startswith("http"):
            return endpoint
        if not endpoint.startswith("/"):
            endpoint = f"/{endpoint}"
        url = f"{self.prefix.rstrip('/')}{endpoint}"
        if query:
            url = f"{url}?{urlencode(query)}"
        return url

    def format_response(self, response: requests.Response) -> dict[str, Any]:
        """Parse JSON and inject response_url for traceability."""
        data = response.json()
        if isinstance(data, dict):
            data["response_url"] = str(response.url)
        else:
            data = {"results": data, "response_url": str(response.url)}
        return data

    def make_request(
        self,
        method: str,
        endpoint: str,
        **kwargs: Any,
    ) -> dict[str, Any]:
        """Execute an HTTP request and return parsed response data."""
        headers = self._get_request_headers()
        url = self.make_url(endpoint)

        logger.debug("API Request: method=%s, url=%s", method.upper(), url)

        with requests.Session() as session:
            response = session.request(
                method.upper(),
                url,
                headers=headers,
                timeout=self.request_timeout,
                **kwargs,
            )

        logger.debug("API Response: status_code=%s, url=%s", response.status_code, response.url)

        if response.status_code >= 400:
            raise {{ cookiecutter.service_name }}APIError.from_response(response)

        if response.status_code == 204:
            return {}

        return self.format_response(response)
