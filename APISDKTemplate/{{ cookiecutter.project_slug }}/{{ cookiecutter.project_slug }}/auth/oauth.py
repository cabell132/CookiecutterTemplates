"""{{ cookiecutter.service_name }} OAuth implementation."""

from __future__ import annotations

from {{ cookiecutter.project_slug }}.auth.base import {{ cookiecutter.service_name }}AuthBase
from {{ cookiecutter.project_slug }}.cache_handler import CacheFileHandler, CacheHandler
from {{ cookiecutter.project_slug }}.exceptions import {{ cookiecutter.service_name }}AuthError


class {{ cookiecutter.service_name }}OAuth({{ cookiecutter.service_name }}AuthBase):
    """Concrete OAuth implementation with pluggable token caching."""

    def __init__(self, cache_handler: CacheHandler | None = None) -> None:
        self.cache_handler = cache_handler or CacheFileHandler()

    def get_access_token(self) -> str:
        """Return a cached token or request a new one."""
        cached = self.cache_handler.get_cached_token()
        if cached and not self._is_expired(cached):
            return str(cached["access_token"])
        token_info = self._request_new_token()
        self.cache_handler.save_token_to_cache(token_info)
        return str(token_info["access_token"])

    @staticmethod
    def _is_expired(token_info: dict) -> bool:  # type: ignore[type-arg]
        """Check if a cached token has expired.

        TODO: Implement expiry logic based on your API's token format.
        """
        return False

    def _request_new_token(self) -> dict:  # type: ignore[type-arg]
        """Request a new OAuth token from the API.

        TODO: Implement the OAuth token exchange for your API.
        """
        raise {{ cookiecutter.service_name }}AuthError(
            message="_request_new_token() not implemented — override this method.",
            error="not_implemented",
        )
