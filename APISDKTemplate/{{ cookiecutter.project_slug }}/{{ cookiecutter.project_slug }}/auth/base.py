"""Abstract base for {{ cookiecutter.service_name }} auth managers."""

from __future__ import annotations

import os

from {{ cookiecutter.project_slug }}.auth.utils import CLIENT_CREDS_ENV_VARS


class {{ cookiecutter.service_name }}AuthBase:
    """Abstract base for authentication managers.

    Subclasses must implement ``get_access_token()``.
    """

    def get_access_token(self) -> str:
        """Return a valid access token."""
        raise NotImplementedError

    @property
    def client_id(self) -> str:
        return os.environ[CLIENT_CREDS_ENV_VARS["client_id"]]

    @property
    def client_username(self) -> str:
        return os.environ[CLIENT_CREDS_ENV_VARS["client_username"]]

    @property
    def client_password(self) -> str:
        return os.environ[CLIENT_CREDS_ENV_VARS["client_password"]]
