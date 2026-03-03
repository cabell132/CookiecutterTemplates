"""Shared test fixtures for {{ cookiecutter.service_name }} SDK tests."""

from __future__ import annotations

from unittest.mock import MagicMock

import pytest

from {{ cookiecutter.project_slug }}.session import {{ cookiecutter.service_name }}Session


@pytest.fixture
def mock_response() -> MagicMock:
    """Create a mock requests.Response."""
    response = MagicMock()
    response.status_code = 200
    response.url = "https://api.example.com/v1/items/"
    response.reason = "OK"
    response.json.return_value = {
        "id": 1,
        "name": "Test Item",
        "slug": "test-item",
        "status": "active",
        "response_url": "https://api.example.com/v1/items/1/",
    }
    return response


@pytest.fixture
def mock_session() -> MagicMock:
    """Create a mock {{ cookiecutter.service_name }}Session."""
    return MagicMock(spec={{ cookiecutter.service_name }}Session)
