"""Tests for {{ cookiecutter.service_name }} exception hierarchy."""

from __future__ import annotations

from unittest.mock import MagicMock

from {{ cookiecutter.project_slug }}.exceptions import (
    {{ cookiecutter.service_name }}APIError,
    {{ cookiecutter.service_name }}AuthError,
    {{ cookiecutter.service_name }}BaseError,
)


def test_api_error_inherits_base_error() -> None:
    assert issubclass({{ cookiecutter.service_name }}APIError, {{ cookiecutter.service_name }}BaseError)


def test_auth_error_inherits_base_error() -> None:
    assert issubclass({{ cookiecutter.service_name }}AuthError, {{ cookiecutter.service_name }}BaseError)


def test_api_error_attributes() -> None:
    error = {{ cookiecutter.service_name }}APIError(
        message="Not Found",
        url="https://api.example.com/items/999/",
        http_status=404,
    )
    assert error.message == "Not Found"
    assert error.url == "https://api.example.com/items/999/"
    assert error.http_status == 404


def test_api_error_str() -> None:
    error = {{ cookiecutter.service_name }}APIError(
        message="Not Found",
        url="https://api.example.com/items/999/",
        http_status=404,
    )
    result = str(error)
    assert "404" in result
    assert "Not Found" in result
    assert "items/999" in result


def test_api_error_from_response() -> None:
    mock_response = MagicMock()
    mock_response.status_code = 422
    mock_response.url = "https://api.example.com/items/"
    mock_response.reason = "Unprocessable Entity"
    mock_response.json.return_value = {"detail": "Validation failed"}

    error = {{ cookiecutter.service_name }}APIError.from_response(mock_response)

    assert error.http_status == 422
    assert error.message == "Validation failed"
    assert "items" in error.url


def test_api_error_from_response_no_json() -> None:
    mock_response = MagicMock()
    mock_response.status_code = 500
    mock_response.url = "https://api.example.com/"
    mock_response.reason = "Internal Server Error"
    mock_response.json.side_effect = ValueError("No JSON")

    error = {{ cookiecutter.service_name }}APIError.from_response(mock_response)

    assert error.http_status == 500
    assert error.message == "Internal Server Error"


def test_auth_error_attributes() -> None:
    error = {{ cookiecutter.service_name }}AuthError(message="Invalid credentials", error="invalid_grant")
    assert error.message == "Invalid credentials"
    assert error.error == "invalid_grant"
