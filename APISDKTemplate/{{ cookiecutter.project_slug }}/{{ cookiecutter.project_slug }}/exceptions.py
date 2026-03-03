"""{{ cookiecutter.service_name }} API exception hierarchy."""

from __future__ import annotations

import logging
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import requests

logger = logging.getLogger(__name__)


class {{ cookiecutter.service_name }}BaseError(Exception):
    """Base error for all {{ cookiecutter.service_name }} SDK exceptions."""


class {{ cookiecutter.service_name }}APIError({{ cookiecutter.service_name }}BaseError):
    """Raised when the API returns an error response."""

    def __init__(
        self,
        message: str,
        url: str,
        http_status: int | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.url = url
        self.http_status = http_status
        logger.error(
            "{{ cookiecutter.service_name }} API Error: %s (http_status=%s, url=%s)",
            message,
            http_status,
            url,
        )

    def __str__(self) -> str:
        return f"http_status={self.http_status}, url={self.url} - {self.message}"

    @classmethod
    def from_response(cls, response: requests.Response) -> {{ cookiecutter.service_name }}APIError:
        """Factory: build an error from a requests.Response."""
        try:
            body = response.json()
            message = body.get("detail", body.get("message", response.reason))
        except Exception:
            message = response.reason or "Unknown error"
        return cls(
            message=str(message),
            url=str(response.url),
            http_status=response.status_code,
        )


class {{ cookiecutter.service_name }}AuthError({{ cookiecutter.service_name }}BaseError):
    """Raised for authentication/authorization failures."""

    def __init__(self, message: str, error: str | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.error = error
        logger.error("{{ cookiecutter.service_name }} Auth Error: %s (error=%s)", message, error)
