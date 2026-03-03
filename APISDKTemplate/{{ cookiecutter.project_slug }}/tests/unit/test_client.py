"""Tests for {{ cookiecutter.service_name }}Client."""

from __future__ import annotations
{% if cookiecutter.auth_mode == "api_key" %}
from unittest.mock import patch


@patch.dict("os.environ", {"{{ cookiecutter.auth_env_var_name }}": "test-key"})
def test_client_has_items_resource() -> None:
    from {{ cookiecutter.project_slug }}.client import {{ cookiecutter.service_name }}Client

    client = {{ cookiecutter.service_name }}Client()
    assert hasattr(client, "items")


@patch.dict("os.environ", {"{{ cookiecutter.auth_env_var_name }}": "test-key"})
def test_client_creates_session() -> None:
    from {{ cookiecutter.project_slug }}.client import {{ cookiecutter.service_name }}Client

    client = {{ cookiecutter.service_name }}Client()
    assert client.session is not None
{% elif cookiecutter.auth_mode == "bearer_token" %}
from {{ cookiecutter.project_slug }}.client import {{ cookiecutter.service_name }}Client


def test_client_has_items_resource() -> None:
    client = {{ cookiecutter.service_name }}Client(auth="test-token")
    assert hasattr(client, "items")


def test_client_creates_session() -> None:
    client = {{ cookiecutter.service_name }}Client(auth="test-token")
    assert client.session is not None
{% elif cookiecutter.auth_mode == "oauth" %}
from {{ cookiecutter.project_slug }}.client import {{ cookiecutter.service_name }}Client


def test_client_has_items_resource() -> None:
    client = {{ cookiecutter.service_name }}Client(auth="test-token")
    assert hasattr(client, "items")


def test_client_creates_session() -> None:
    client = {{ cookiecutter.service_name }}Client(auth="test-token")
    assert client.session is not None
{% endif %}
