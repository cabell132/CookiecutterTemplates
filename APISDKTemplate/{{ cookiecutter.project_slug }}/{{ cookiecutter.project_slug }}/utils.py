"""Utility helpers for {{ cookiecutter.service_name }} SDK."""

from __future__ import annotations

from urllib.parse import parse_qs, urlparse


def add_scheme_to_url(url: str, scheme: str = "https") -> str:
    """Ensure a URL has a scheme prefix."""
    if url and not url.startswith(("http://", "https://")):
        return f"{scheme}://{url}"
    return url


def extract_url_parameters(url: str) -> tuple[str, str, dict[str, str]]:
    """Extract base URL, path, and query parameters from a URL.

    Returns:
        A tuple of (base_url, path, query_params).
    """
    parsed = urlparse(url)
    base_url = f"{parsed.scheme}://{parsed.netloc}"
    path = parsed.path
    query_params = {k: v[0] for k, v in parse_qs(parsed.query).items()}
    return base_url, path, query_params
